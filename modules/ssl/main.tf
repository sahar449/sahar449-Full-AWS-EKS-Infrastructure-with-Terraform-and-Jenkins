### main ssl ###

data "aws_route53_zone" "selected" {
  name         = "saharbittman.com."
  private_zone = false
}

resource "aws_acm_certificate" "ssl_cert" {
  domain_name       = "saharbittman.com"
  validation_method = "DNS"

  subject_alternative_names = [
    "*.saharbittman.com" 
  ]

  tags = {
    Name = "saharbittman-ssl"
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.ssl_cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id = data.aws_route53_zone.selected.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "cert" {
  certificate_arn         = aws_acm_certificate.ssl_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}
