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

# Create DynamoDB Tables only for main functions
resource "aws_dynamodb_table" "tables" {
  for_each = toset(["MOALZ-Prod", "MOALZ-Test"])

  name         = each.key
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }

  global_secondary_index {
    name               = "IdTimestampIndex"
    hash_key           = "id"
    range_key          = "timestamp"
    projection_type    = "ALL"
  }
}

# Map backend functions to their corresponding main tables
locals {
  table_mapping = {
    "MOALZ-Prod"          = "MOALZ-Prod"
    "MOALZ-Test"          = "MOALZ-Test"
    "MOALZ-Backend-Prod"  = "MOALZ-Prod"
    "MOALZ-Backend-Test"  = "MOALZ-Test"
  }
  
  # Environment-specific variables
  prod_env_vars = {
    EXPERIENCE_ID  = "V3TulUHbjyHYi0Gp1R41"
    MOLZAIT_API_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ2ZXJzaW9uIjoiMSIsImFjY291bnRJZCI6Imdsb2NrbGJyYXUtMTcxM2FiODdlIiwicmVzdGF1cmFudElkIjoiZ2xvY2tsYnJhdS0xNzEzYWI4N2UiLCJhcGlLZXlJZCI6InR4RW9ZQldyeGhmTkVMOGZBVDgyIiwibmFtZSI6Ik9uc2FpIiwiaWF0IjoxNzQwNjYyMzYyLCJpc3MiOiJtb2x6YWl0In0.dbdQR6FC_ZISHfORa96gO_DHfTegLP4zsFfzvKGdACU"
    PINECONE_INDEX = "molzait-prod"
  }
  
  test_env_vars = {
    EXPERIENCE_ID  = "pqNVgQ7Il6Ys7K9S4FK8"
    MOLZAIT_API_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ2ZXJzaW9uIjoiMSIsImFjY291bnRJZCI6Im9uc2FpLTIxOTM3N2QyYzdjMjQ4IiwicmVzdGF1cmFudElkIjoib25zYWktMjE5Mzc3ZDJjN2MyNDgiLCJhcGlLZXlJZCI6InRXTmF5WEMzUFJIR2dRelhMZlBwIiwibmFtZSI6Ik9uc2FpIFRlbGVmb25ib3QiLCJpYXQiOjE3MzY3ODAzODgsImlzcyI6Im1vbHphaXQifQ.7YQUGB2HyS6HqVWYXJpJsqeug8svHN9frGnG8lyhoik"
    PINECONE_INDEX = "molzait-test"
  }
  
  # Common environment variables
  common_env_vars = {
    GROQ_API_KEY = "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"
    PINECONE_API_KEY = "ea1a3e6e-d621-4702-b46d-734ccf89d693"
    AZURE_LLM_KEY = "TAihtadL8X9b263quD8frhAeK6MRqAnF"
    AZURE_LLM_URL = "https://Llama-3-3-70B-Instruct-smriv.swedencentral.models.ai.azure.com"
    MS_TEAMS_WEBHOOK_URL = "https://onsai.webhook.office.com/webhookb2/26484e92-ecdc-430a-be34-dc6f7eda4c72@b4fbe58b-de74-48d4-a087-a8a136e7c172/IncomingWebhook/48f416857b1747188c4e0a0233f12739/9fbebde3-6342-42b0-bfdd-d66ff1d6c123/V2hJSlY1dMzh-tYrbCCq5CCbhjm481tPrgZUAJD1CzmNw1"
    OPENAI_API_AZURE_EMBEDDING = "McDreamsEmbedding"
    OPENAI_API_AZURE_KEY = "e5b5786d55d84b47a9f0530831118a17"
    OPENAI_AZURE_BASE_URL = "https://mcdreams.openai.azure.com/"
    PINECONE_ENVIRONMENT = "eu-west4-gcp"
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
  
  # Set timeout to 5 minutes
  timeout        = 300
  
  # Set memory size to 512 MB for backend functions
  memory_size    = contains(["MOALZ-Backend-Test", "MOALZ-Backend-Prod"], each.key) ? 512 : 128

  # Specify the architecture
  architectures = ["x86_64"]

  # Add environment variables based on environment (Prod or Test)
  environment {
    variables = each.key == "MOALZ-Prod" ? merge(
      { DYNAMO_DB_TABLE = aws_dynamodb_table.tables[local.table_mapping[each.key]].name },
      local.common_env_vars,
      local.prod_env_vars
    ) : contains(["MOALZ-Backend-Prod"], each.key) ? merge(
      { DYNAMO_DB_TABLE = aws_dynamodb_table.tables[local.table_mapping[each.key]].name },
      local.common_env_vars, 
      local.prod_env_vars
    ) : merge(
      { DYNAMO_DB_TABLE = aws_dynamodb_table.tables[local.table_mapping[each.key]].name },
      local.common_env_vars,
      local.test_env_vars
    )
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
