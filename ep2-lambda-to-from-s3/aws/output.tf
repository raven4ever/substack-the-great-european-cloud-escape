output "input_bucket" {
  value = aws_s3_bucket.input.id
}

output "output_bucket" {
  value = aws_s3_bucket.output.id
}

output "function_arn" {
  value = aws_lambda_function.resizer.arn
}
