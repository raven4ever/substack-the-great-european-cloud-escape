# Episode 2: Serverless Image Resizer

A serverless function that generates thumbnails from images uploaded to an S3 bucket. Deployed on both AWS and Scaleway to compare the event-driven architectures.

## Architecture

**AWS:** S3 upload → S3 Event Notification → Lambda → thumbnail in output bucket

**Scaleway:** S3 upload → (manual) SQS message → Serverless Function → thumbnail in output bucket

> Scaleway doesn't support native S3 event notifications. The upload script sends an SQS message manually — the step that AWS handles transparently.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install)
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) (used for both AWS and Scaleway S3/SQS operations)
- [Docker](https://docs.docker.com/get-docker/) — both providers package dependencies inside a Docker container to produce Linux-compatible binaries (Pillow has native C extensions)

### Docker images used

| Provider | Image                                                             | Purpose                                                  |
| -------- | ----------------------------------------------------------------- | -------------------------------------------------------- |
| AWS      | `public.ecr.aws/sam/build-python3.13`                             | SAM build image matching the Lambda runtime              |
| Scaleway | `rg.fr-par.scw.cloud/scwfunctionsruntimes-public/python-dep:3.13` | Scaleway's own function runtime for dependency packaging |

> The AWS build adds `--platform linux/amd64` to force x86_64 emulation to ensure AMD64 architecture event when running from Apple Silicon. The Scaleway image is amd64-only, so Docker handles this automatically.

## Project Structure

```
lambda/          # Shared Python handler (one entry point per provider)
aws/             # Terraform config: S3 + Lambda + IAM
scaleway/        # Terraform config: S3 + SQS + Serverless Function + IAM
upload/          # Test scripts for uploading images and polling results
```

## AWS Deployment

Configure your AWS credentials (`aws configure` or environment variables), then:

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
export SCW_ACCESS_KEY="<your-access-key>"
export SCW_SECRET_KEY="<your-secret-key>"
export SCW_DEFAULT_ORGANIZATION_ID="<your-org-id>"
export SCW_DEFAULT_PROJECT_ID="<your-project-id>"
```

```bash
cd scaleway
terraform init
terraform apply
```

This creates:

- Input and output Object Storage buckets
- SQS activation, queue, and two credential sets (publisher + consumer)
- IAM application with scoped Object Storage permissions and a dedicated API key for the function
- Serverless Function namespace and function with Pillow
- SQS trigger wiring the queue to the function

## Testing

### AWS

```bash
cd upload
./aws.sh test-image.jpg
```

Uploads the image to the input bucket, waits for the Lambda to process it, and downloads the thumbnail.

### Scaleway

The upload script requires `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` set to credentials with Object Storage access (for the `aws s3 cp` upload step):

```bash
export AWS_ACCESS_KEY_ID="<your-scw-access-key>"
export AWS_SECRET_ACCESS_KEY="<your-scw-secret-key>"
```

```bash
cd upload
./scaleway.sh test-image.jpg
```

Uploads the image to the input bucket, sends an SQS notification (the step AWS handles natively), waits for the function to process it, and downloads the thumbnail.

## Key Differences

|                        | AWS                                  | Scaleway                                          |
| ---------------------- | ------------------------------------ | ------------------------------------------------- |
| Event trigger          | Native S3 → Lambda                   | Manual SQS message required                       |
| Credentials            | IAM execution role (no keys in code) | IAM application API keys as env vars              |
| IAM scoping            | Resource-level (per-bucket ARN)      | Project-level (all buckets in project)            |
| Dependency packaging   | SAM build image                      | Scaleway runtime image                            |
| Credential sets needed | 0 (IAM role handles it)              | 3 (IAM API key, S3 upload key, SQS publisher key) |

## Cleanup

```bash
cd aws && terraform destroy
cd scaleway && terraform destroy
```
