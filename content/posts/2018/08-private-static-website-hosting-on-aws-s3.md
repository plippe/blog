---
title: "Private static website hosting on AWS S3"
date: 2018-08-01

tags: ["amazon web services", "simple storage service"]
---

There are plenty of options to host static websites. An obvious one would be [GitHub pages](https://pages.github.com/). This can deploy pages found in a directory, or found in a branch. It is great if you have a public resource to publish, but it can’t handle private ones. For those cases, I would recommend [AWS S3](https://aws.amazon.com/s3/).

Hosting a website on AWS S3 doesn’t need much effort. Once a bucket has [website hosting enabled](https://docs.aws.amazon.com/AmazonS3/latest/dev/EnableWebsiteHosting.html), and the appropriate permissions, all files in the bucket will be accessible online.

```
[BUCKET].s3-website-[REGION].amazonaws.com/[FILE]
```

This gives us a public website like GitHub pages. It is perfect as CDN, but we must configure it to host private files.

AWS S3 doesn’t support any authentication method. You can’t enable basic authentication, nor limit access based on a header, or a query argument. But, AWS S3 can block, or allow a set of IP addresses.

Blocking all requests, but those sent from specific internet connections is a simple way of securing resources. It can be achieve with the following bucket policy.

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": "*",
    "Action": "s3:GetObject",
    "Resource": "arn:aws:s3:::[BUCKET]/[GLOB]",
    "Condition": {
      "IpAddress": {
        "aws:SourceIp": [
          "[IP1]",
          "[IP2]",
          ...
        ]
      }
    }
  }]
}
```

Amazon has a great guide to [add bucket policies](https://docs.aws.amazon.com/AmazonS3/latest/user-guide/add-bucket-policy.html), so I will show how to add the policy with [AWS CLI](https://aws.amazon.com/cli/).

AWS CLI has two different S3 "service", `s3`, and `s3api`. The first is a lighter version of the second. For example, both have a way of creating a bucket, but only the latter can configure the resource.

The first step is to create the bucket. Bucket names must be unique. Avoid very generic names, and you should be fine.

```sh
MY_BUCKET=plippe-s-bucket
aws s3api create-bucket --bucket $MY_BUCKET
```

Next, we must enable website hosting, and configure it.

```sh
aws s3api put-bucket-website \
  --bucket $MY_BUCKET \
  --website-configuration '{
    "IndexDocument": {
      "Suffix": "index.html"
    },
    "ErrorDocument": {
      "Key": "error.html"
    }
  }'
```

Finaly, we must change the permissions to only allow read access from given IP addresses.

```sh
MY_IP=$(curl --silent -4 ifconfig.co)
aws s3api put-bucket-policy \
  --bucket ${MY_BUCKET} \
  --policy '{
    "Version": "2012-10-17",
    "Statement": {
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::'${MY_BUCKET}'/*",
      "Condition": {
        "IpAddress": {
          "aws:SourceIp": "'${MY_IP}'/32"
        }
      }
    }
  }'
```

To test our private website, we will upload a simple file. By specifying the content type, your browser will render the file instead of downloading it.

```sh
echo 'Hello, World!' > index.html
aws s3api put-object \
  --bucket $MY_BUCKET \
  --key index.html \
  --body index.html \
  --content-type text/html
```

Once all is done, our `Hello, World!` should be accessible online.

```sh
MY_REGION=$(aws configure get region)
curl http://${MY_BUCKET}.s3-website-${MY_REGION}.amazonaws.com/
```

Private static websites are rarely required. Next time you do need to host, and share, confidential files, don’t use a full blown server, S3 will work fine.
