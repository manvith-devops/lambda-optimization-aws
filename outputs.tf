output "lambda_name" {
  value = aws_lambda_function.processor.function_name
}

output "s3_bucket" {
  value = aws_s3_bucket.data_bucket.bucket
}

output "dynamodb_table" {
  value = aws_dynamodb_table.results.name
}