#!/usr/bin/env bash
BUCKET=carsaver-deployment-scripts
DIR=scripts/
aws s3 sync $DIR s3://$BUCKET/
