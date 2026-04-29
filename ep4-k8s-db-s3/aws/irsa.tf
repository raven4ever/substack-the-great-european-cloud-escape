data "tls_certificate" "eks_oidc" {
  url = local.oidc_issuer_url
}

resource "aws_iam_openid_connect_provider" "eks" {
  url             = local.oidc_issuer_url
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_oidc.certificates[0].sha1_fingerprint]

  tags = {
    Name    = format("%s-eks-oidc", local.app_name)
    Project = local.project
  }
}

resource "aws_iam_role" "app" {
  name               = format("%s-app-irsa", local.app_name)
  assume_role_policy = data.aws_iam_policy_document.app_irsa_assume_role.json

  tags = {
    Name    = format("%s-app-irsa", local.app_name)
    Project = local.project
  }
}

resource "aws_iam_policy" "app_s3_access" {
  name        = format("%s-app-s3", local.app_name)
  description = "App access to the animal-images bucket"
  policy      = data.aws_iam_policy_document.app_s3_access.json
}

resource "aws_iam_role_policy_attachment" "app_s3_access" {
  role       = aws_iam_role.app.name
  policy_arn = aws_iam_policy.app_s3_access.arn
}
