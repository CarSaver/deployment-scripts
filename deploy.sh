#!/usr/bin/env bash

# Check variables are set
AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION?"Need to set AWS_DEFAULT_REGION"}
ECS_CLUSTER=${ECS_CLUSTER?"Need to set ECS_CLUSTER"}
ECS_SERVICE=${ECS_SERVICE?"Need to set ECS_SERVICE"}
ECS_TASK_DEFINITION=${ECS_TASK_DEFINITION?"Need to set ECS_TASK_DEFINITION"}
ECR_REPO_NAME=${ECR_REPO_NAME?"Need to set ECR_REPO_NAME"}
APP_ENVIRONMENT=${APP_ENVIRONMENT?"Need to set APP_ENVIRONMENT"}

# Task Definition Template
ECS_TASK_TEMPLATE=$(<ecs_template.json)

ECS_TASK_TEMPLATE=${ECS_TASK_TEMPLATE?"Unable to load ecs_template.json"}

make_task_def() {
	task_def=$(printf "$ECS_TASK_TEMPLATE" $ECS_TASK_DEFINITION $AWS_ACCOUNT_ID $AWS_DEFAULT_REGION $ECR_REPO_NAME $CIRCLE_SHA1 $SENDGRID_API_KEY $APP_ENVIRONMENT $ECS_SERVICE $AWS_DEFAULT_REGION)
}

# more bash-friendly output for jq
JQ="jq --raw-output --exit-status"

configure_aws_cli() {
	aws --version
	aws configure set default.region ${AWS_DEFAULT_REGION}
	aws configure set default.output json
}

deploy_cluster() {
    make_task_def
    register_definition
    if [[ $(aws ecs update-service --cluster $ECS_CLUSTER --service $ECS_SERVICE --task-definition $revision | \
                   $JQ '.service.taskDefinition') != $revision ]]; then
        echo "Error updating lead service."
        return 1
    fi

    # wait for older revisions to disappear
    # not really necessary, but nice for demos
    for attempt in {1..30}; do
        if stale=$(aws ecs describe-services --cluster $ECS_CLUSTER --services $ECS_SERVICE | \
                       $JQ ".services[0].deployments | .[] | select(.taskDefinition != \"$revision\") | .taskDefinition"); then
            echo "Waiting for stale deployments:"
            echo "$stale"
            sleep 5
        else
            echo "Deployed!"
            return 0
        fi
    done
    echo "Service update took too long."
    return 1
}

push_ecr_image() {
	eval $(aws ecr get-login --region $AWS_DEFAULT_REGION)
	docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$ECR_REPO_NAME:$CIRCLE_SHA1
}

register_definition() {

    if revision=$(aws ecs register-task-definition --container-definitions "$task_def" --family $ECS_TASK_DEFINITION | $JQ '.taskDefinition.taskDefinitionArn'); then
        echo "Revision: $revision"
    else
        echo "Failed to register task definition"
        return 1
    fi

}

configure_aws_cli
push_ecr_image
deploy_cluster
