output "alb_domain" {
  value = aws_lb.api_server.dns_name
}

output "api_vpc_cloudfront_origin_id" {
  value = aws_cloudfront_vpc_origin.api_server.id
}