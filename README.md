# Deployment Scripts

Common deployment scripts for CarSaver deployments.

## Deploying to ECS from CircleCI

### ECS Task Definition Template

Your project will need a file called `ecs_template.json` that will outline what the task definition will be for your project.  [ecs_template.example.json](ecs_template.example.json) is an example you can look at to start.

### CircleCI Setup

1. You need to make sure the AWS Permissions have been set for the CircleCI Project.
2. You also need to add the Environment Variable `AWS_ACCOUNT_ID` on your CircleCI project.  The value for this can be found in ECR. It's the first few digits of the ECR Repository location.

### `circle.yml` Setup

Add the following to your `circle.yml`:

```yaml
machine:
  # THESE ENVIRONMENT VARIABLES ARE USED IN THE deploy.sh SCRIPT. CHANGE THE VALUES AS NEEDED.
  environment:
    AWS_DEFAULT_REGION: us-east-1
    ECS_SERVICE: iam-service
    ECS_TASK_DEFINITION: iam-service-definition
    ECR_REPO_NAME: carsaver/iam-service
test:
  post:
    # THIS WILL DOWNLOAD THE deploy.sh SCRIPT FROM GITHUB
    - curl -o deploy.sh https://raw.githubusercontent.com/CarSaver/deployment-scripts/master/deploy.sh?token=AACz8wl_JVUvCAfj8ql--yQuNrntAHHxks5XfRM1wA%3D%3D
    - chmod a+x deploy.sh
deployment:
  # CHOOSE THE CLUSTER TO DEPLOY TO FOR EACH DEPLOYMENT STAGE.
  stage:
    branch: develop
    commands:
      - ECS_CLUSTER=carsaver-staging APP_ENVIRONMENT=stage ./deploy.sh
  prod:
    branch: master
    commands:
      - ECS_CLUSTER=carsaver-production APP_ENVIRONMENT=prod ./deploy.sh
```

You can use some of the environment variables above that are required for the deploy script in your docker build command as well. e.g.

```sh
docker build -t $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$ECR_REPO_NAME:$CIRCLE_SHA1 .
```

__NOTE__ `$AWS_ACCOUNT_ID` must be configured on your CircleCI Project.
