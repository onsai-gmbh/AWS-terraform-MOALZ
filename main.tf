# main.tf

#############################################
# AWS Provider Configuration
#############################################

provider "aws" {
  region  = var.aws_region
  profile = "onsai"  # Specify the AWS CLI profile to use
}

#############################################
# IAM Role and Policies for Lambda Functions
#############################################

# Allow Lambda service to assume the role
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# Create IAM Role for Lambda
resource "aws_iam_role" "lambda_role_MOALZ" {
  name               = "lambda_role_MOALZ"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

# Attach the AWSLambdaBasicExecutionRole policy
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_role_MOALZ.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Define IAM Policy for DynamoDB Access
data "aws_iam_policy_document" "dynamodb_access_MOALZ" {
  statement {
    actions   = ["dynamodb:*"]
    resources = ["*"]
  }
}

# Create IAM Policy for DynamoDB Access
resource "aws_iam_policy" "dynamodb_access_MOALZ" {
  name   = "LambdaDynamoDBAccessMOALZ"
  policy = data.aws_iam_policy_document.dynamodb_access_MOALZ.json
}

# Attach the DynamoDB Access Policy to the Lambda Role
resource "aws_iam_role_policy_attachment" "lambda_dynamodb_access_MOALZ" {
  role       = aws_iam_role.lambda_role_MOALZ.name
  policy_arn = aws_iam_policy.dynamodb_access_MOALZ.arn
}

#############################################
# IAM Policy for AWS Bedrock Access
#############################################

data "aws_iam_policy_document" "bedrock_access" {
  statement {
    actions = [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream",
      "bedrock:ListFoundationModels",
      "bedrock:ListCustomModels",
      "bedrock:GetModel",
      "bedrock:ListModels",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "bedrock_access_MOALZ" {
  name   = "LambdaBedrockAccessMOALZ"
  policy = data.aws_iam_policy_document.bedrock_access.json
}

resource "aws_iam_role_policy_attachment" "lambda_bedrock_access_MOALZ" {
  role       = aws_iam_role.lambda_role_MOALZ.name
  policy_arn = aws_iam_policy.bedrock_access_MOALZ.arn
}

#############################################
# DynamoDB Tables
#############################################

# Create DynamoDB Tables for each Lambda Function
resource "aws_dynamodb_table" "tables" {
  for_each = toset(var.lambda_functions)

  name         = each.key
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

#############################################
# Lambda Layer
#############################################

# Create a Lambda Layer for Python Packages
resource "aws_lambda_layer_version" "python_packages-MOALZ" {
  filename            = "layers/python_packages.zip"
  layer_name          = "python_packages-MOALZ"
  compatible_runtimes = [var.lambda_runtime]
  source_code_hash    = filebase64sha256("layers/python_packages.zip")
}

#############################################
# Lambda Functions
#############################################

# Create Lambda Functions
resource "aws_lambda_function" "functions" {
  for_each       = toset(var.lambda_functions)
  filename       = "lambda/lambda_function.zip"
  function_name  = each.key
  role           = aws_iam_role.lambda_role_MOALZ.arn
  handler        = var.lambda_handler
  runtime        = var.lambda_runtime
  source_code_hash = filebase64sha256("lambda/lambda_function.zip")
  layers         = [aws_lambda_layer_version.python_packages-MOALZ.arn]
  timeout        = 300  # Set the timeout to 300 seconds (5 minutes)

  # Specify the architecture
  architectures = ["x86_64"]

  # Add environment variables
  environment {
    variables = {
      DYNAMO_DB_TABLE   = aws_dynamodb_table.tables[each.key].name
      GROQ_API_KEY = "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"
      PINECONE_API_KEY = "ea1a3e6e-d621-4702-b46d-734ccf89d693"
    }
  }
}

#############################################
# API Gateway HTTP API (v2) Configuration
#############################################

# Create HTTP APIs for each Lambda Function
resource "aws_apigatewayv2_api" "http_api" {
  for_each      = toset(var.lambda_functions)
  name          = each.key
  protocol_type = "HTTP"
}

# Create a default stage
resource "aws_apigatewayv2_stage" "default_stage" {
  for_each    = aws_apigatewayv2_api.http_api
  api_id      = each.value.id
  name        = "$default"
  auto_deploy = true
}

# Create Lambda Integration
resource "aws_apigatewayv2_integration" "lambda_integration" {
  for_each               = aws_apigatewayv2_api.http_api
  api_id                 = each.value.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.functions[each.key].arn
  payload_format_version = "2.0"
}

# Create $default route
resource "aws_apigatewayv2_route" "default_route" {
  for_each  = aws_apigatewayv2_api.http_api
  api_id    = each.value.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration[each.key].id}"
}

# Get AWS Account ID
data "aws_caller_identity" "current" {}

# Grant API Gateway permission to invoke Lambda
resource "aws_lambda_permission" "apigw_lambda" {
  for_each      = aws_apigatewayv2_api.http_api
  statement_id  = "AllowAPIGatewayInvoke-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.functions[each.key].function_name
  principal     = "apigateway.amazonaws.com"

  # The source ARN follows this format:
  # arn:aws:execute-api:{region}:{account_id}:{api_id}/*/*

  source_arn = "arn:aws:execute-api:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${each.value.id}/*/*"
}
