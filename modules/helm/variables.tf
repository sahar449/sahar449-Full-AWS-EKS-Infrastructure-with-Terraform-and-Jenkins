### variabels helm ###

variable "region" {
  description = "AWS Region"
}

variable "oidc_provider_arn" {
  description = "OIDC ARN of your EKS account"
}

variable "oidc_provider_url" {
  description = "OIDC URL of your EKS account"
}

variable "cluster_name" {
  description = "The name of the EKS cluster"
}

variable "domain_name" {
  type    = string
  default = "saharbittman.com"
}

variable "vpc_id" {
}

variable "ssl_certificate_validation_resource" {
  description = "The SSL certificate validation resource to depend on"
  type        = any
}
