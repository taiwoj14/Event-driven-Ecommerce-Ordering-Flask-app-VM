# Data source to fetch the Route 53 Hosted Zone ID by domain name
data "aws_route53_zone" "main" {
  name         = var.domain # Replace with your actual domain name
  private_zone = false
}

# ACM Certificate
resource "aws_acm_certificate" "main" {
  domain_name       = "*.tai-joh.com" # Replace with your actual domain name
  validation_method = "DNS"

  tags = {
    Name = "app-cert"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Route 53 Record for ACM Validation
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id = data.aws_route53_zone.main.zone_id # Reference the zone ID here
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.record]

  depends_on = [aws_acm_certificate.main]
}

