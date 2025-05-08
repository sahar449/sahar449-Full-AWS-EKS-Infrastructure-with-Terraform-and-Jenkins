### outputs ssl ###

output "ssl_cert_arn" {
  value = aws_acm_certificate_validation.cert.certificate_arn
}

output "ssl_certificate_validation_resource" {
  value = aws_acm_certificate_validation.cert
}
