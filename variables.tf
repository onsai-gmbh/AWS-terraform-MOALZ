# variables.tf

variable "aws_region" {
  description = "AWS Region"
  default     = "eu-central-1"
}

variable "lambda_functions" {
  description = "List of Lambda function names"
  default     = [
    "MOALZ-Prod",
    "MOALZ-Test"
  ]
}

variable "lambda_runtime" {
  description = "Runtime for Lambda functions"
  default     = "python3.13"
}

variable "lambda_handler" {
  description = "Handler for Lambda functions"
  default     = "lambda_function.lambda_handler"
}
