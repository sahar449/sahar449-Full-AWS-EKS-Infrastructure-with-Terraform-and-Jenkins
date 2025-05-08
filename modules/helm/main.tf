# 1. Basic AWS Information
data "aws_caller_identity" "current" {}

# Random String Generator
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

###################################
# 2. Load Balancer Controller Resources
###################################

# 2.1 Load Balancer Controller IAM Role and Policy
data "aws_iam_policy" "lb_controller_policy" {
  name = "AWSLoadBalancerControllerIAMPolicy"
}

resource "aws_iam_role" "lb_controller_role" {
  name = "eks-lb-controller-role-${random_string.suffix.result}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${replace(var.oidc_provider_url, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lb_controller_attach" {
  role       = aws_iam_role.lb_controller_role.name
  policy_arn = data.aws_iam_policy.lb_controller_policy.arn
}

# 2.2 Load Balancer Controller Service Account
resource "kubernetes_service_account" "aws_load_balancer_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"

    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.lb_controller_role.arn
    }
  }
}

# 2.3 Load Balancer Controller Helm Release
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.7.1"

  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = kubernetes_service_account.aws_load_balancer_controller.metadata[0].name
  }

  set {
    name  = "region"
    value = var.region
  }

  set {
    name  = "vpcId"
    value = var.vpc_id
  }

  set {
    name  = "aws.loadBalancerControllerRoleArn"
    value = aws_iam_role.lb_controller_role.arn
  }

  depends_on = [
    aws_iam_role.lb_controller_role,
    kubernetes_service_account.aws_load_balancer_controller
  ]
}

###################################
# 3. External DNS Resources
###################################

# 3.1 External DNS IAM Policy and Role
resource "aws_iam_policy" "external_dns_policy" {
  name        = "ExternalDNSIAMPolicy-${random_string.suffix.result}"
  description = "IAM policy for External DNS to manage Route53 records"
  policy      = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "route53:ChangeResourceRecordSets",
          "route53:ListResourceRecordSets",
          "route53:ListHostedZones",
          "route53:ListTagsForResource"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role" "external_dns_role" {
  name = "eks-external-dns-role-${random_string.suffix.result}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${replace(var.oidc_provider_url, "https://", "")}:sub" = "system:serviceaccount:kube-system:external-dns"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "external_dns_attach" {
  role       = aws_iam_role.external_dns_role.name
  policy_arn = aws_iam_policy.external_dns_policy.arn
}

resource "aws_iam_role_policy_attachment" "dns_controller_policy" {
  role       = aws_iam_role.external_dns_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonRoute53FullAccess"
}

# 3.2 External DNS Service Account
resource "kubernetes_service_account" "external_dns" {
  metadata {
    name      = "external-dns"
    namespace = "kube-system"

    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.external_dns_role.arn
    }
  }
}

# 3.3 External DNS Helm Release
resource "helm_release" "external_dns" {
  name       = "external-dns"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "external-dns"
  namespace  = "kube-system"
  version    = "6.33.0"

  set {
    name  = "provider"
    value = "aws"
  }

  set {
    name  = "aws.zoneType"
    value = "public"
  }

  set {
    name  = "aws.region"
    value = var.region
  }

  set {
    name  = "txtOwnerId"
    value = var.cluster_name
  }

  set {
    name  = "policy"
    value = "upsert-only"
  }

  set {
    name  = "domainFilters[0]"
    value = "saharbittman.com"
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = kubernetes_service_account.external_dns.metadata[0].name
  }

  set {
    name  = "sources[0]"
    value = "service"
  }

  set {
    name  = "sources[1]"
    value = "ingress"
  }

  set {
    name  = "ingress.publishInternalIngresses"
    value = "false"
  }

  set {
    name  = "serviceAccount.annotations.eks.amazonaws.com/role-arn"
    value = aws_iam_role.external_dns_role.arn
  }

  depends_on = [
    helm_release.aws_load_balancer_controller
  ]
}

###################################
# 4. Application Deployment
###################################

# 4.1 Flask Application Deployment
# resource "kubernetes_deployment" "flask_app" {
#   depends_on = [
#     helm_release.aws_load_balancer_controller,
#     helm_release.external_dns
#   ]

#   metadata {
#     name      = "flask-app-${random_string.suffix.result}"
#     namespace = "default"
#   }

#   spec {
#     replicas = 2

#     selector {
#       match_labels = {
#         app = "flask-app-${random_string.suffix.result}"
#       }
#     }

#     template {
#       metadata {
#         labels = {
#           app = "flask-app-${random_string.suffix.result}"
#         }
#       }

#       spec {
#         container {
#           name  = "flask-app"
#           image = "${data.aws_caller_identity.current.account_id}.dkr.ecr.us-west-2.amazonaws.com/my-app:latest"

#           port {
#             container_port = 80
#           }

#           liveness_probe {
#             http_get {
#               path = "/healthz"
#               port = 80
#             }
#             initial_delay_seconds = 5
#             period_seconds        = 10
#             timeout_seconds       = 2
#             failure_threshold     = 3
#             success_threshold     = 1
#           }
#         }
#       }
#     }
#   }
# }

# # 4.2 Flask Service
# resource "kubernetes_service" "flask_service" {
#   metadata {
#     name      = "flask-service-${random_string.suffix.result}"
#     namespace = "default"
#   }

#   spec {
#     selector = {
#       app = "flask-app-${random_string.suffix.result}"
#     }

#     port {
#       port        = 80
#       target_port = 80
#     }

#     type = "ClusterIP"
#   }

#   depends_on = [
#     helm_release.external_dns,
#     helm_release.aws_load_balancer_controller,
#     kubernetes_deployment.flask_app
#   ]
# }

# # 4.3 Flask Ingress
# resource "kubernetes_ingress_v1" "flask_ingress" {
#   metadata {
#     name      = "ingress-flask-${random_string.suffix.result}"
#     namespace = "default"

#     annotations = {
#       # Load Balancer
#       "alb.ingress.kubernetes.io/load-balancer-name"        = "ingress-${random_string.suffix.result}"
#       "kubernetes.io/ingress.class"                         = "alb"
#       "alb.ingress.kubernetes.io/scheme"                    = "internet-facing"

#       # Target Type
#       "alb.ingress.kubernetes.io/target-type"               = "ip"

#       # Health Checks
#       "alb.ingress.kubernetes.io/healthcheck-protocol"      = "HTTP"
#       "alb.ingress.kubernetes.io/healthcheck-port"          = "traffic-port"
#       "alb.ingress.kubernetes.io/healthcheck-interval-seconds" = "15"
#       "alb.ingress.kubernetes.io/healthcheck-timeout-seconds"  = "5"
#       "alb.ingress.kubernetes.io/success-codes"             = "200"
#       "alb.ingress.kubernetes.io/healthy-threshold-count"   = "2"
#       "alb.ingress.kubernetes.io/unhealthy-threshold-count" = "2"

#       # SSL
#       "alb.ingress.kubernetes.io/listen-ports"              = "[{\"HTTPS\":443}, {\"HTTP\":80}]"
#       "alb.ingress.kubernetes.io/ssl-policy"                = "ELBSecurityPolicy-TLS-1-2-2017-01"
#       "alb.ingress.kubernetes.io/ssl-redirect"              = "443"

#       # External DNS
#       "external-dns.alpha.kubernetes.io/hostname"           = "saharbittman.com"
#     }
#   }

#   spec {
#     ingress_class_name = "alb"

#     # TLS Configuration
#     tls {
#       hosts = [
#         "*.saharbittman.com"
#       ]
#     }

#     rule {
#       http {
#         path {
#           path      = "/"
#           path_type = "Prefix"

#           backend {
#             service {
#               name = kubernetes_service.flask_service.metadata[0].name
#               port {
#                 number = 80
#               }
#             }
#           }
#         }
#       }
#     }
#   }

#   depends_on = [
#     helm_release.external_dns,
#     helm_release.aws_load_balancer_controller
#   ]
# }