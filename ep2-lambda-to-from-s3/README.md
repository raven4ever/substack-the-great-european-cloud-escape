# Episode 2: Serverless Image Resizer

A serverless function that generates thumbnails from images uploaded to an S3 bucket. Deployed on both AWS and Scaleway to compare the event-driven architectures.

## Architecture

**AWS:** S3 upload → S3 Event Notification → Lambda → thumbnail in output bucket

**Scaleway:** S3 upload → (manual) SQS message → Serverless Function → thumbnail in output bucket

## Prerequisites

- Terraform
- AWS CLI (used for both AWS and Scaleway S3/SQS operations)
- Python 3.14
- Docker (for building Lambda/Function packages with Linux-compatible dependencies)

## Project Structure

```
lambda/          # Shared Python function code (one handler per provider)
aws/             # Terraform config for AWS (S3 + Lambda + IAM)
scaleway/        # Terraform config for Scaleway (S3 + SQS + Serverless Function)
upload/          # Test scripts for uploading images and polling results
```

## AWS Deployment

```bash
cd aws
terraform init
terraform apply
```

This creates:

- Input and output S3 buckets
- IAM role with least-privilege access (GetObject on input, PutObject on output)
- Lambda function with Pillow for image resizing
- S3 event notification that triggers the function on upload

## Scaleway Deployment

Export your Scaleway credentials:

```bash
export SCW_ACCESS_KEY="your-access-key"
export SCW_SECRET_KEY="your-secret-key"
export SCW_DEFAULT_PROJECT_ID="your-project-id"
export SCW_DEFAULT_REGION="fr-par"
export TF_VAR_scw_access_key=$SCW_ACCESS_KEY
export TF_VAR_scw_secret_key=$SCW_SECRET_KEY
```

```bash
cd scaleway
terraform init
terraform apply
```

This creates:

- Input and output Object Storage buckets
- SQS activation, queue, and two credential sets (publisher + consumer)
- Serverless Function namespace and function with Pillow
- SQS trigger wiring the queue to the function

## Testing

### AWS

```bash
cd upload
./aws.sh path/to/image.jpg
```

Uploads the image to the input bucket, waits for the Lambda to process it, and downloads the thumbnail.

### Scaleway

```bash
cd upload
./scaleway.sh path/to/image.jpg
```

Uploads the image to the input bucket, sends an SQS notification (the step AWS handles natively), waits for the function to process it, and downloads the thumbnail.

## Key Differences

|                        | AWS                                  | Scaleway                        |
| ---------------------- | ------------------------------------ | ------------------------------- |
| Event trigger          | Native S3 → Lambda                   | Manual SQS message required     |
| Credentials            | IAM execution role (no keys in code) | Access keys as env vars         |
| Dependency layers      | Lambda Layers supported              | Everything bundled in one zip   |
| Credential sets needed | 0 (IAM role handles it)              | 3 (API keys, S3 keys, SQS keys) |

## Cleanup

```bash
cd aws && terraform destroy
cd scaleway && terraform destroy
```
