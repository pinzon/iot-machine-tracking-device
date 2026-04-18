#!/usr/bin/env bash
set -euo pipefail

export AWS_PROFILE=personal
STACK_NAME="machine-tracker-iot"
LAMBDA_BUCKET="cris-lambdas"
LAMBDA_KEY="receiver.zip"
TEMPLATE_FILE="backend.yml"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

cd "$SCRIPT_DIR"

echo "Packaging Lambda code..."
zip -j receiver.zip receiver.py

echo "Uploading Lambda zip to s3://${LAMBDA_BUCKET}/${LAMBDA_KEY}..."
aws s3 cp receiver.zip "s3://${LAMBDA_BUCKET}/${LAMBDA_KEY}"

echo "Deploying CloudFormation stack: ${STACK_NAME}..."
aws cloudformation deploy \
  --template-file "$TEMPLATE_FILE" \
  --stack-name "$STACK_NAME" \
  --capabilities CAPABILITY_IAM \
  --parameter-overrides \
    LambdaBucket="$LAMBDA_BUCKET" \
    LambdaKey="$LAMBDA_KEY"

echo "Updating Lambda function code..."
aws lambda update-function-code \
  --function-name iot-data-processor \
  --s3-bucket "$LAMBDA_BUCKET" \
  --s3-key "$LAMBDA_KEY" \
  --no-cli-pager

echo "Done."
