#!/bin/bash

# Script to set S3 bucket public access for bullet-services
# Make sure you have AWS CLI configured with appropriate permissions

BUCKET_NAME="bullet-services"
REGION="eu-north-1"

echo "Setting up public access for S3 bucket: $BUCKET_NAME"

# 1. Disable block public access settings
echo "Disabling block public access settings..."
aws s3api put-public-access-block \
  --bucket $BUCKET_NAME \
  --public-access-block-configuration \
  "BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false"

# 2. Set bucket policy for public read access
echo "Setting bucket policy for public read access..."
aws s3api put-bucket-policy \
  --bucket $BUCKET_NAME \
  --policy '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Sid": "PublicReadGetObject",
        "Effect": "Allow",
        "Principal": "*",
        "Action": "s3:GetObject",
        "Resource": "arn:aws:s3:::'$BUCKET_NAME'/*"
      }
    ]
  }'

echo "S3 bucket $BUCKET_NAME has been configured for public read access"
echo "Note: You may need to wait a few minutes for changes to take effect"
