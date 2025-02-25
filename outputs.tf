# outputs.tf

output "api_urls" {
  value = {
    for name, api in aws_apigatewayv2_api.http_api :
    name => api.api_endpoint
  }
}