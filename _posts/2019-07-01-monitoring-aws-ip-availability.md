---
layout: post
title: Monitoring AWS IP availability

tags: ["aws web services", "aws lambda"]
---

Running virtual private cloud, or VPC, on AWS is common, and even required in some cases.

VPCs are virtual networks. They logically group AWS resources. Those instances are either connected to the internet, or not thanks to subnets. All the relevant information is very well documented on [Amazon’s website](https://docs.aws.amazon.com/vpc/latest/userguide/what-is-amazon-vpc.html).

Resources can be added to VPCs, and subnets as long as those have available IPs. Running out of addresses will make it impossible to launch new instances. This will impact services that automatically scale, like lambdas.

There are many opinions on how to pick the right size, and I doubt mine has any real value. Instead, I will show how to monitor available ips.

## Code
To avoid dealing with a full server, the application is best as an AWS Lambda. Any runtime with a quick cold start should work. I picked JavaScript.

The [`describeSubnets`](https://docs.aws.amazon.com/AWSJavaScriptSDK/latest/AWS/EC2.html#describeSubnets-property) function, on the EC2 object, return subnets.

```javascript
const AWS = require("aws-sdk");
const EC2 = new AWS.EC2();

EC2.describeSubnets({}, (err, data) => {
  if (err !== null) console.error(err, err.stack);
  if (data !== null) console.log(data);
});
```

The result, `data`, contains only a single page. Using the `NextToken` parameter is a solution, but the [`eachPage`](https://docs.aws.amazon.com/AWSJavaScriptSDK/latest/AWS/Request.html#eachPage-property), and the [`eachItem`](https://docs.aws.amazon.com/AWSJavaScriptSDK/latest/AWS/Request.html#eachItem-property) function is easier.

```javascript
const AWS = require("aws-sdk");
const EC2 = new AWS.EC2();

EC2.describeSubnets().eachItem((err, data) => {
  if (err !== null) console.error(err, err.stack);
  if (data !== null) console.log(data);
});
```

AWS requests have another limitation. `describeSubnets` only returns subnets for a given region. The one in the environment, or an explicit one when creating the EC2 object.

```javascript
const AWS = require("aws-sdk");
const EC2 = new AWS.EC2({
  region: "us-east-1"
});
```

To retrieve all subnets, the application must call the function with each region.

```javascript
const AWS = require("aws-sdk");

const forEachSubnet = (region, callback) => {
  const EC2 = new AWS.EC2({
    region: region
  });

  EC2.describeSubnets().eachItem((err, data) => {
    if (err !== null) console.error(err, err.stack);
    if (data !== null) callback(data);
  });
};

forEachSubnet("us-east-1", console.log);
forEachSubnet("us-east-2", console.log);
```

Hard coding a list of region isn’t a viable solution. [`describeRegions`](https://docs.aws.amazon.com/AWSJavaScriptSDK/latest/AWS/EC2.html#describeRegions-property) is preferable. It retrieve every available region on AWS.

```javascript
const AWS = require("aws-sdk");
const EC2 = new AWS.EC2();

const forEachRegion = callback => {
  EC2.describeRegions().eachItem((err, data) => {
    if (err !== null) console.error(err, err.stack);
    if (data !== null) callback(data);
  });
};

forEachRegion(region =>
  forEachSubnet(region.RegionName, console.log)
);
```

The subnets objects have useful information to extract. Identifiers, and the `AvailableIpAddressCount` attribute are obvious choices. The total amount of IP addresses isn’t available on the object, but via the [`CidrBlock`](https://en.wikipedia.org/wiki/Classless_Inter-Domain_Routing). Instead of reinventing the wheel, the [ip-cidr package](https://www.npmjs.com/package/ip-cidr) offers a quick solution.

```javascript
const IPCIDR = require("ip-cidr");

const ipAddressCount = cidrStr => {
  const cidr = new IPCIDR(cidrStr);
  return cidr.isValid() ? cidr.toArray().length : 0;
};
```

Once gathered, the application can push the data to AWS CloudWatch for alarms.

```javascript
const CloudWatch = require("./aws/cloudwatch");

const params = {
  Namespace: "subnet-ip-availability",
  MetricData: ...
};

CloudWatch.putMetricData(params, (err, data) => {
  if (err !== null) console.error(err, err.stack);
});
```

With the code finished, it needs to be deployed to AWS.

## Infrastructure
AWS has three official ways to create resources: the console, the [command line interface](https://aws.amazon.com/cli/), and CloudFormation. The last option takes a bit of time, but guaranties the infrastructure to be the same each time.

The main resource is the [AWS Lambda function](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-lambda-function.html). It requires a role.

```yml
AWSTemplateFormatVersion: "2010-09-09"
Description: AWS Lambda IP Availability
Parameters:
  Name:
    Type: String
    Default: "aws-lambda-ip-availability"
Resources:
  Role:
    Type: AWS::IAM::Role
    Properties:
      RoleName: !Ref Name
      AssumeRolePolicyDocument:
        Version: "2012-10-17"
        Statement:
          -
            Effect: "Allow"
            Action: "sts:AssumeRole"
            Principal:
              Service: "lambda.amazonaws.com"
  Function:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: !Ref Name
      Role: !GetAtt Role.Arn
      Runtime: "nodejs8.10" # nodejs10.x doesn't support zip file
      Handler: "index.handler"
      Code:
        ZipFile: "//"
```

AWS Lambda writes to CloudWatch Logs. Their role needs the permissions to interact with Log Groups, and Log Streams.

```yml
LogGroup:
  Type: AWS::Logs::LogGroup
  Properties:
    RetentionInDays: 7
    LogGroupName: !Join [ "", [ "/aws/lambda/", !Ref Name ] ]
RoleCloudWatchLog:
  Type: AWS::IAM::Policy
  Properties:
    PolicyName: !Join [ "", [ !Ref Name, "-cloudwatch-log" ] ]
    PolicyDocument:
      Version: "2012-10-17"
      Statement:
        -
          Effect: "Allow"
          Action: "logs:CreateLogGroup"
          Resource: !Join [ "", [ "arn:aws:logs:", !Ref "AWS::Region", ":", !Ref "AWS::AccountId", ":log-group:", !Ref LogGroup ] ]
        -
          Effect: "Allow"
          Action:
            - "logs:CreateLogStream"
            - "logs:PutLogEvents"
          Resource: !GetAtt LogGroup.Arn
    Roles:
      - !Ref Role
```

The application also interacts with EC2, and CloudWatch.

```yml
RoleEc2:
  Type: AWS::IAM::Policy
  Properties:
    PolicyName: !Join [ "", [ !Ref Name, "-ec2" ] ]
    PolicyDocument:
      Version: "2012-10-17"
      Statement:
        -
          Effect: "Allow"
          Action:
            - "ec2:DescribeRegions"
            - "ec2:DescribeSubnets"
          Resource: "*"
    Roles:
      - !Ref Role
RoleCloudWatchMetric:
  Type: AWS::IAM::Policy
  Properties:
    PolicyName: !Join [ "", [ !Ref Name, "-cloudwatch-metric" ] ]
    PolicyDocument:
      Version: "2012-10-17"
      Statement:
        -
          Effect: "Allow"
          Action: "cloudwatch:PutMetricData"
          Resource: "*"
    Roles:
      - !Ref Role
```

The template can also hold a periodic event to trigger the application.

```yml
Event:
  Type: AWS::Events::Rule
  Properties:
    Name: !Ref Name
    ScheduleExpression: "rate(1 hour)"
    Targets:
      -
        Id: "Target-1"
        Arn: !GetAtt Function.Arn
EventPermission:
  Type: AWS::Lambda::Permission
  Properties:
    Principal: "events.amazonaws.com"
    Action: "lambda:InvokeFunction"
    FunctionName: !Ref Function
    SourceArn: !GetAtt Event.Arn
```

Every execution puts metrics on CloudWatch to trigger alarms.

## Alarms
[AWS CloudWatch Alarm](https://console.aws.amazon.com/cloudwatch/home?region=us-east-1) monitor metrics. When certain conditions are met, a notification is sent to an SNS topic. All subscribers will receive it too. Those can be email addresses, phone numbers, HTTP endpoints, and more.

The metric should either be the amount of available IPs, or the percentage of remaining ones.

When this metric is below an acceptable threshold, the alarm should message the SNS topic. This will draw attention to the subnet to add another, or replace it by a larger one.

Adding alarms for every subnet is quite a repetitive task. Using the CLI, or building a small application can make the process less of a chore. Something for the next post … maybe.

---

Running out of available IPs is a silly move that can happen to anyone. The errors are rarely displayed in the appropriate service making it very hard to debug. This little application, [available on GitHub](https://github.com/plippe/aws-lambda-ip-availability), will hopefully avoid a few sleepless nights.
