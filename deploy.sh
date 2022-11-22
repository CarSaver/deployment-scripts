#!/usr/bin/env bash

# Check variables are set
AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION?"Need to set AWS_DEFAULT_REGION"}
ECS_CLUSTER=${ECS_CLUSTER?"Need to set ECS_CLUSTER"}
ECS_SERVICE=${ECS_SERVICE?"Need to set ECS_SERVICE"}
ECS_TASK_DEFINITION=${ECS_TASK_DEFINITION?"Need to set ECS_TASK_DEFINITION"}
ECR_REPO_NAME=${ECR_REPO_NAME?"Need to set ECR_REPO_NAME"}
BUGSNAG_API_KEY=${BUGSNAG_API_KEY?"Need to set BUGSNAG_API_KEY"}
DD_TRACE_ANALYTICS_ENABLED=${DD_TRACE_ANALYTICS_ENABLED:-false}
DD_LOGS_INJECTION=${DD_LOGS_INJECTION:-false}
int ECS_TASK_MEM = $((ECS_TASK_MEMORY))
ECS_TASK_MEMORY=${ECS_TASK_MEMORY}

# more bash-friendly output for jq
JQ="jq --raw-output --exit-status"

# Task Definition Template
curl "https://raw.githubusercontent.com/CarSaver/deployment-scripts/v4.0/ecs_template.base.json" > ecs_template.base.json
$JQ --raw-output --exit-status -s '.[0][0] * .[1][0]' ecs_template.base.json ecs_template.json | cat <(echo '[') <(cat -) <(echo ']') > ecs_template_new.json
ECS_TASK_TEMPLATE=$(<ecs_template_new.json)

ECS_TASK_TEMPLATE=${ECS_TASK_TEMPLATE?"Unable to load ecs_template_new.json"}

ECS_TASK_TEMPLATE="${ECS_TASK_TEMPLATE//\"/\\\"}"

make_task_def() {
	task_def="$(eval echo $ECS_TASK_TEMPLATE)"
}

configure_aws_cli() {
	aws --version
	aws configure set default.region ${AWS_DEFAULT_REGION}
	aws configure set default.output json
}

deploy_cluster() {
    make_task_def
    register_definition
		notify_bugsnag
    if [[ $(aws ecs update-service --cluster $ECS_CLUSTER --service $ECS_SERVICE --task-definition $revision | \
                   $JQ '.service.taskDefinition') != $revision ]]; then
        echo "Error updating service."
        return 1
    fi

    # wait for older revisions to disappear
    # not really necessary, but nice for demos
    for attempt in {1..60}; do
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

notify_bugsnag() {
	BUGSNAG_RELEASE_STAGE=$([ "$SPRING_PROFILES_ACTIVE" == "prod" ] && echo "production" || echo "$SPRING_PROFILES_ACTIVE")

	IFS=',' # Set delimiter to comma
	read -ra API_KEYS <<< "$BUGSNAG_API_KEY"
	for API_KEY in "${API_KEYS[@]}"; do
		bugsnag_notifier="curl https://notify.bugsnag.com/deploy -X POST -d \"apiKey=${API_KEY}&releaseStage=${BUGSNAG_RELEASE_STAGE}&repository=${CIRCLE_REPOSITORY_URL}&revision=${CIRCLE_SHA1}&branch=\\\"${CIRCLE_BRANCH}\\\"\""
		echo $bugsnag_notifier
		eval $bugsnag_notifier
	done
	IFS=' ' # Set delimiter back to default
	echo ""
}

push_ecr_image() {
	eval $(aws ecr get-login --region $AWS_DEFAULT_REGION | sed 's/ -e none//g')
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
