data "aws_iam_policy_document" "lbc_irsa_assume_role" {
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
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }

    condition {
      test     = "StringEquals"
      variable = format("%s:aud", local.oidc_issuer_host_path)
      values   = ["sts.amazonaws.com"]
    }
  }
}

data "http" "alb_controller_iam_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.14.1/docs/install/iam_policy.json"
}

resource "aws_iam_policy" "lbc" {
  name        = format("%s-alb-controller", local.app_name)
  description = "AWS Load Balancer Controller IAM policy"
  policy      = data.http.alb_controller_iam_policy.response_body
}

resource "aws_iam_role" "lbc" {
  name               = "aws-load-balancer-controller"
  assume_role_policy = data.aws_iam_policy_document.lbc_irsa_assume_role.json

  tags = {
    Name    = "aws-load-balancer-controller"
    Project = local.project
  }
}

resource "aws_iam_role_policy_attachment" "lbc" {
  role       = aws_iam_role.lbc.name
  policy_arn = aws_iam_policy.lbc.arn
}

resource "helm_release" "aws_load_balancer_controller" {
  name            = "aws-load-balancer-controller"
  repository      = "https://aws.github.io/eks-charts"
  chart           = "aws-load-balancer-controller"
  namespace       = "kube-system"
  upgrade_install = true

  set = [
    {
      name  = "clusterName"
      value = aws_eks_cluster.app.name
    },
    {
      name  = "serviceAccount.create"
      value = "true"
    },
    {
      name  = "serviceAccount.name"
      value = "aws-load-balancer-controller"
    },
    {
      name  = "region"
      value = data.aws_region.current.id
    },
    {
      name  = "vpcId"
      value = aws_vpc.app.id
    },
    {
      name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = aws_iam_role.lbc.arn
    },
  ]

  depends_on = [
    aws_eks_node_group.app,
    aws_iam_role_policy_attachment.lbc,
    aws_eks_access_policy_association.terraform_caller_admin,
  ]
}

