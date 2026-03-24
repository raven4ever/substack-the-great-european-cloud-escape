# Episode 1: Static Websites

A static website hosted in an S3 bucket and served through a CDN. Deployed on AWS (S3 + CloudFront), Scaleway (Object Storage + Edge Services), and Scaleway using the AWS Terraform provider.

## Architecture

**AWS:** S3 bucket (website mode) → CloudFront distribution

**Scaleway:** Object Storage bucket (website mode) → Edge Services (pipeline → backend → cache → DNS)

**Scaleway with AWS provider:** Same S3 bucket on Scaleway, but managed using the `hashicorp/aws` Terraform provider pointed at Scaleway's S3 endpoint.

## Prerequisites

- Terraform
- AWS CLI (configured for AWS deployments)
- Scaleway CLI / credentials (configured for Scaleway deployments)

## Project Structure

```
website/                    # Static site files (index.html, error.html, styles.css)
aws/                        # Terraform config for AWS (S3 + CloudFront)
scaleway/                   # Terraform config for Scaleway (Object Storage + Edge Services)
scaleway-with-aws-provider/ # Terraform config using AWS provider against Scaleway S3
```

## AWS Deployment

```bash
cd aws
terraform init
terraform apply
```

Outputs:

- `bucket_website_url` — direct S3 website endpoint
- `cdn_website_url` — CloudFront distribution domain

## Scaleway Deployment

Export your Scaleway credentials:

```bash
export SCW_ACCESS_KEY="your-access-key"
export SCW_SECRET_KEY="your-secret-key"
export SCW_DEFAULT_PROJECT_ID="your-project-id"
export SCW_DEFAULT_REGION="fr-par"
```

```bash
cd scaleway
terraform init
terraform apply
```

Outputs:

- `bucket_website_url` — direct Object Storage website endpoint
- `cdn_website_url` — Edge Services domain

## Scaleway with AWS Provider

This variant proves that Scaleway's S3 compatibility is real — the same `aws_s3_*` resources work against Scaleway's endpoint.

```bash
export AWS_ACCESS_KEY_ID=$SCW_ACCESS_KEY
export AWS_SECRET_ACCESS_KEY=$SCW_SECRET_KEY
```

```bash
cd scaleway-with-aws-provider
terraform init
terraform apply
```

## Cleanup

```bash
cd aws && terraform destroy
cd scaleway && terraform destroy
cd scaleway-with-aws-provider && terraform destroy
```
