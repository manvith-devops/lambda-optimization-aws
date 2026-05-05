variable "region" {
  default = "us-east-1"
}

variable "lambda_memory" {
  description = "Lambda memory size for testing"
  default     = 128
}

variable "lambda_timeout" {
  default = 30
}

variable "project_name" {
  default = "lambda-optimization"
}