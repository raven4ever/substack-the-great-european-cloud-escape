data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "app" {
  name               = format("%s-role", local.app_name)
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json

  tags = {
    Project = "ep3-lb-asg-vms"
  }
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "app" {
  name = format("%s-profile", local.app_name)
  role = aws_iam_role.app.name

  tags = {
    Project = "ep3-lb-asg-vms"
  }
}
