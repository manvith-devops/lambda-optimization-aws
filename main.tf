provider "aws" {
  region = var.region
}

# ---------------------------
# S3 Bucket
# ---------------------------
resource "aws_s3_bucket" "data_bucket" {
  bucket = "${var.project_name}-data-${random_id.rand.hex}"
}

resource "random_id" "rand" {
  byte_length = 4
}

# ---------------------------
# DynamoDB Table
# ---------------------------
resource "aws_dynamodb_table" "results" {
  name         = "${var.project_name}-results"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

# ---------------------------
# IAM Role for Lambda
# ---------------------------
resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# ---------------------------
# IAM Policy
# ---------------------------
resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.project_name}-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # S3 Read
      {
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:ListBucket"]
        Resource = [
          aws_s3_bucket.data_bucket.arn,
          "${aws_s3_bucket.data_bucket.arn}/*"
        ]
      },
      # DynamoDB Write
      {
        Effect = "Allow"
        Action = ["dynamodb:PutItem", "dynamodb:BatchWriteItem"]
        Resource = aws_dynamodb_table.results.arn
      },
      # Logs
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      },
      # X-Ray
      {
        Effect = "Allow"
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords"
        ]
        Resource = "*"
      }
    ]
  })
}

# ---------------------------
# Lambda Function
# ---------------------------
resource "aws_lambda_function" "processor" {
  function_name = "${var.project_name}-lambda"

  filename         = "lambda.zip"
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.11"
  role             = aws_iam_role.lambda_role.arn

  memory_size      = var.lambda_memory
  timeout          = var.lambda_timeout

  source_code_hash = filebase64sha256("lambda.zip")

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.data_bucket.bucket
      TABLE_NAME  = aws_dynamodb_table.results.name
    }
  }

  tracing_config {
    mode = "Active"
  }
}

# ---------------------------
# CloudWatch Log Group
# ---------------------------
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.processor.function_name}"
  retention_in_days = 7
}