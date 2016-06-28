#!/usr/bin/env bash
BUCKET=deployment-scripts
DIR=scripts/
aws s3 sync $DIR s3://$BUCKET/
