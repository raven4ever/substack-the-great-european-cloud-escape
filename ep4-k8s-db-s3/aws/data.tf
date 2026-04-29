data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_iam_session_context" "current" {
  arn = data.aws_caller_identity.current.arn
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_iam_policy_document" "eks_cluster_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "eks_nodes_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_ecr_authorization_token" "token" {}

data "aws_eks_cluster_auth" "cluster" {
  name = aws_eks_cluster.app.name
}

data "aws_iam_policy_document" "app_irsa_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }

    condition {
      test     = "StringEquals"
      variable = format("%s:sub", local.oidc_issuer_host_path)
      values   = [format("system:serviceaccount:%s:%s", local.app_sa_namespace, local.app_sa_name)]
    }

    condition {
      test     = "StringEquals"
      variable = format("%s:aud", local.oidc_issuer_host_path)
      values   = ["sts.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "app_s3_access" {
  statement {
    sid    = "BucketLevel"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]
    resources = [aws_s3_bucket.animal_images.arn]
  }

  statement {
    sid    = "ObjectLevel"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = [format("%s/*", aws_s3_bucket.animal_images.arn)]
  }
}

