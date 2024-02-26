terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "ph-tfstate-ap-ne2-common-bucket-1"
    key = "petclinic/dev"
    region = "ap-northeast-2"
  }
}

provider "aws" {
  region = "ap-northeast-2"
}

provider "kubernetes" {
  host = module.eks.cluster_endpoint
  token = data.aws_eks_cluster_auth.main.token
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    token                  = data.aws_eks_cluster_auth.main.token
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  }
}
