resource "aws_iam_role" "lambda" {
  name               = format("%s-role", local.function_name)
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_policy" "lambda_s3" {
  name   = format("%s-s3-access", local.function_name)
  policy = data.aws_iam_policy_document.lambda_s3.json
}

resource "aws_iam_role_policy_attachment" "lambda_s3" {
  role       = aws_iam_role.lambda.name
  policy_arn = aws_iam_policy.lambda_s3.arn
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
