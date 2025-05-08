### main root ###

module "vpc" {
  source                = "./modules/vpc"
  vpc_cidr              = var.vpc_cidr
  public_subnet_cidrs   = var.public_subnet_cidrs
  private_subnet_cidrs  = var.private_subnet_cidrs
  availability_zones    = var.availability_zones
  name_prefix = var.name_prefix
}

module "eks" {
  source             = "./modules/eks"
  cluster_name       = var.cluster_name
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
}

module "helm" {
  source          = "./modules/helm"
  cluster_name    = var.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
  region = var.region
  vpc_id = module.eks.eks_vpc_id
  ssl_certificate_validation_resource = module.ssl.ssl_certificate_validation_resource
}

module "ssl" {
  source = "./modules/ssl"
}
