### outputs helm ####
output "external_dns_release_name" {
  value = helm_release.external_dns.metadata[0].name
}

output "alb_controller_release_name" {
  value = helm_release.aws_load_balancer_controller.metadata[0].name
}
