locals {
  cluster_name = "ph-petclinic-eks-${random_string.suffix.result}"
  lb_controller_service_account_name = "aws-load-balancer-controller"
}

data "aws_eks_cluster_auth" "main" {
  name = local.cluster_name
}

resource "random_string" "suffix" {
  length  = 8
  special = false
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.15.3"

  cluster_name    = local.cluster_name
  cluster_version = "1.29"

  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.private_subnets
  cluster_endpoint_public_access = true

  eks_managed_node_group_defaults = {
    ami_type = "AL2_x86_64"

  }

  eks_managed_node_groups = {
    one = {
      name = "ph-petclinic-ng-1"

      instance_types = ["t3.medium"]
      
      min_size     = 1
      max_size     = 3
      desired_size = 2
    }

    two = {
      name = "ph-petclinic-ng-2"

      instance_types = ["t3.medium"]

      min_size     = 1
      max_size     = 2
      desired_size = 1
    }
  }
}

data "aws_iam_policy" "ebs_csi_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

module "irsa-ebs-csi" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "4.7.0"

  create_role                   = true
  role_name                     = "AmazonEKSTFEBSCSIRole-${module.eks.cluster_name}"
  provider_url                  = module.eks.oidc_provider
  role_policy_arns              = [data.aws_iam_policy.ebs_csi_policy.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
}

resource "aws_eks_addon" "ebs-csi" {
  cluster_name             = module.eks.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = "v1.20.0-eksbuild.1"
  service_account_role_arn = module.irsa-ebs-csi.iam_role_arn
  tags = {
    "eks_addon" = "ebs-csi"
    "terraform" = "true"
  }
}

module "lb_controller_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "4.7.0"
  
  create_role = true
  role_name        = "AmazonEKSTFALBRole-${module.eks.cluster_name}"
  provider_url = module.eks.oidc_provider
  role_policy_arns             = [aws_iam_policy.controller.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:kube-system:${local.lb_controller_service_account_name}"]
}

data "http" "ingress_controller_policy_json" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.0/docs/install/iam_policy.json"
}

resource "aws_iam_policy" "controller" {
  name_prefix = "AmazonLoadBalancerControllerPolicy"
  policy      = data.http.ingress_controller_policy_json.response_body
}

resource "aws_iam_role_policy_attachment" "additional" {
  for_each = module.eks.eks_managed_node_groups

  policy_arn = aws_iam_policy.controller.arn
  role       = each.value.iam_role_name
}