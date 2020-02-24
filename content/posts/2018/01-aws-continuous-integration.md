---
title: "AWS continuous integration"
date: 2018-01-01

series: "aws ci cd"
tags: ["amazon web services", "continuous integration"]
---

[Travis CI](https://travis-ci.org/), [Circle CI](https://circleci.com/), and many others, are great services. They help people create pipelines to build, test, and, if they wish, deploy code. They shortens the development loop, but they do come with their limits. To avoid confidentiality, and security headaches, let me introduce you to [AWS CodeBuild](https://aws.amazon.com/codebuild/).

AWS CodeBuild is like the previously mentioned solutions. It has webhooks, it runs on dockerized environments, and it executes scripts. Furthermore, it can interact with other AWS services without sharing credentials. It ticks all the boxes, but does require a bit more configuration.

AWS CodeBuild has [many settings](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-codebuild-project.html). Most help it fit in the AWS ecosystem, but those can be ignored to mimic the other services. Here are the important ones:
- ServiceRole represent the AWS IAM Role used by AWS CodeBuild to run the build. The role must at least be able to interact with CloudWatch logs to output the execution progress. Extra policies can be added to interact with other AWS services. If other AWS services are required, add more they you can interact interact interact.
- Environment.Image defines the docker image used for the container. This can be a very generic image like alpine, a language specific one, ruby, or a custom made one.
- Environment.PrivilegedMode gives the docker container access to the host’s devices. This is required to run a docker daemon within a container.
- Source.BuildSpec lists the commands to execute, in a [specific format](https://docs.aws.amazon.com/codebuild/latest/userguide/build-spec-ref.html). Those will run in the docker container, and at the root of the source. AWS CodeBuild can also use a file named buildspec.yml instead of the property.

The following CloudFormation template has all the requirements for an AWS CodeBuild project. It gives sensible defaults for all parameters to avoid errors.

```yaml
Parameters:
  CodeBuildProjectName:
    Type: String
    Default: 'my-codebuild-project'
  CodeBuildProjectEnvironmentImage:
    Type: String
    Default: alpine
  CodeBuildProjectSourceGitHub:
    Type: String
    Default: 'https://github.com/plippe/plippe.github.io'
  CodeBuildProjectSourceBuildSpec:
    Type: String
    Default: |
      version: 0.2
      phases:
        build:
          commands:
          - echo Hello World

Resources:
  CodeBuildRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Action: ['sts:AssumeRole']
            Effect: Allow
            Principal:
              Service: [codebuild.amazonaws.com]
      Path: /
      Policies:
        - PolicyName: CodeBuildAccess
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Action:
                - 'logs:CreateLogGroup'
                - 'logs:CreateLogStream'
                - 'logs:PutLogEvents'
                Effect: Allow
                Resource: '*'
  CodeBuildProject:
    Type: AWS::CodeBuild::Project
    Properties:
      Name: !Ref CodeBuildProjectName
      ServiceRole: !Ref CodeBuildRole
      Environment:
        Type: LINUX_CONTAINER
        ComputeType: BUILD_GENERAL1_SMALL
        Image: !Ref CodeBuildProjectEnvironmentImage
     Source:
        Type: GITHUB
        Location: !Ref CodeBuildProjectSourceGitHub
        BuildSpec: !Ref CodeBuildProjectSourceBuildSpec
     Artifacts:
        Type: no_artifacts
```

AWS Cloudformation doesn’t have a webhook property for CodeBuild. To add the webhook, the stack must be created, and AWS must have the proper GitHub permissions. If the permissions haven’t already been granted, AWS requests them when a new project is created on the AWS Console.

```sh
aws create-webhook --project-name my-codebuild-project
```

The build specification currently only outputs the very original "Hello World". For a continuous integration solution, running the tests would be the right action.

```yaml
version: 0.2
phases:
  build:
    commands:
      - echo Testing - # run tests
```

Beware, for automatic deployment, only push the master branch to production.

```yaml
version: 0.2
  phases:
    build:
      commands:
        - echo Testing
        - # run my test
        - |
          # git must be installed
          if [ $(git rev-parse --abbrev-ref HEAD) == 'master' ]
          then
            echo Releasing master
            # deploy to production
          fi
```

AWS CodeBuild is a great continuous integration solution. It can be a continuous deployment one too. Why would you pay for another service when you already have all the tools you need ?
