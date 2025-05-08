provider "aws" {
  region = var.region
}

# provider for AWS EKS authentication
# This data resource retrieves the authentication token for connecting to the EKS cluster.
data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}


provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_ca)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_ca)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.7.0"
    }
  }

  backend "s3" {
    bucket = "sahar-bucketttttt"
    key    = "test/terraform.tfstate"
    region = "us-west-2"
    #use_lockfile = true #lock file
  }
}

