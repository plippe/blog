# Simple docker on Google Cloud
Amazon Web Service offers various services. Most of these are composable to build very specific infrastructures. This flexibility comes at a cost, a financial one, but also a complexity one. This makes AWS a poor solution for simple web projects.

A few alternatives exist like Heroku and OpenShift. These services forward web traffic to a particular port of a docker container. This might not be flexible to meet all needs but is enough for some. Google Cloud has a similar solution, Cloud Run.

Below describes the steps required to get your web application running on Google Cloud Run.

## Web Application
Not looking to focus on the app

Any dockerized application should work

Google expects the port to be set to the PORT environment variable

```dockerfile
FROM python:3-alpine
ENTRYPOINT python3 -m http.server ${PORT}
```

# Google Cloud SDK
The first step is to set up the environment. Google has already gone through the trouble of writing an installation guide. 

For the gcloud tool to interact on our behalf, it requires your credentials. Those can be obtained with the gcloud auth login command. 

```sh
> gcloud auth login

Your browser has been opened to visit:
https://accounts.google.com/o/oauth2/auth?...

You are now logged in as [p.vinchon@gmail.com].
Your current project is [None]. You can change this setting by running:
  $ gcloud config set project PROJECT_ID
```

glcoud should have access to our account. 

## Create a project
```sh
> gcloud projects create example-$RANDOM
Create in progress for [.../projects/example-11536].
Waiting for [...] to finish...done.
Enabling service [...] on project [example-11536]...
Operation "..." finished successfully.
```
