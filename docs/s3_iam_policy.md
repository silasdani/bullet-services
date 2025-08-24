# S3 IAM Policy for bullet-services-s3 User

## Issue
The IAM user `bullet-services-s3` is getting an `AccessDenied` error when trying to upload files to S3:
```
User: arn:aws:iam::930271538212:user/bullet-services-s3 is not authorized to perform: s3:PutObject on resource: "arn:aws:s3:::bullet-services/*"
```

## Required IAM Policy
The `bullet-services-s3` user needs the following IAM policy attached:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:DeleteObject",
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::bullet-services",
                "arn:aws:s3:::bullet-services/*"
            ]
        }
    ]
}
```

## Steps to Fix

1. **Go to AWS IAM Console**
   - Navigate to IAM → Users → bullet-services-s3

2. **Attach Policy**
   - Click "Add permissions"
   - Choose "Attach policies directly"
   - Create a new policy with the JSON above or attach an existing one

3. **Alternative: Use AWS CLI**
   ```bash
   aws iam put-user-policy \
     --user-name bullet-services-s3 \
     --policy-name S3AccessPolicy \
     --policy-document file://s3-policy.json
   ```

## S3 Bucket Configuration
The S3 bucket `bullet-services` has public access blocked, which is correct for security. The application is now configured to:
- Upload files as private objects (`acl: private`)
- Generate signed URLs for access when needed
- Not require public read access

## Testing
After applying the IAM policy, test the image upload functionality to ensure S3 access works correctly.
