resource "kubernetes_deployment" "app_deployment" {
  metadata {
    name = "ph-clinic-app-deployment"

    labels = {
      "app.kubernetes.io/name"       = "app"
      "app.kubernetes.io/version"    = "0.1"
      "app.kubernetes.io/component"  = "deployment"
      "app.kubernetes.io/part-of"    = "petclinic"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  spec {
    replicas = 3

    selector {
      match_labels = {
        "app.kubernetes.io/name"      = "app"
        "app.kubernetes.io/component" = "pod"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"       = "app"
          "app.kubernetes.io/instance"   = "app"
          "app.kubernetes.io/version"    = "0.1"
          "app.kubernetes.io/component"  = "pod"
          "app.kubernetes.io/part-of"    = "petclinic"
          "app.kubernetes.io/managed-by" = "terraform"
        }
      }

      spec {
        termination_grace_period_seconds = 30
        
        security_context {
          run_as_non_root = true
          run_as_user = 999  
        }
        
        container {
          name              = "app"
          image             = "901371017570.dkr.ecr.ap-northeast-2.amazonaws.com/ph-petclinic-common-ecr-1:latest"

          liveness_probe {
            http_get {
              path = "/healthcheck"
              port = 8080
            }
            
            failure_threshold = 2
            initial_delay_seconds = 30
            period_seconds        = 10
          }
        }
      }
    }

    strategy {
      rolling_update {
        max_unavailable = 1
        max_surge = 0
      }
    }
  }
}

resource "kubernetes_service" "app_service" {
  metadata {
    name = "ph-clinic-app-service"

    labels = {
      "app.kubernetes.io/name"       = "app"
      "app.kubernetes.io/instance"   = "app"
      "app.kubernetes.io/version"    = "0.1"
      "app.kubernetes.io/component"  = "service"
      "app.kubernetes.io/part-of"    = "petclinic"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  spec {
    selector = {
      "app.kubernetes.io/name"      = "app"
      "app.kubernetes.io/component" = "pod"
    }

    port {
      port = 8080
      target_port = 8080
    }
    type = "NodePort"
  }
}

resource "helm_release" "app_alb_controller" {
  name       = "aws-load-balancer-controller"
  chart      = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  namespace  = "kube-system"
  set {
    name = "region"
    value = "ap-northeast-2"
  }

  set {
    name = "vpcId"
    value = module.vpc.vpc_id
  }

  set {
    name = "image.repository"
    value = "602401143452.dkr.ecr.ap-northeast-2.amazonaws.com/amazon/aws-load-balancer-controller"
  }

  set {
    name = "serviceAccount.create"
    value = "true"
  }

  set {
    name = "serviceAccount.name"
    value = local.lb_controller_service_account_name
  }
  
  set {
    name = "clusterName"
    value = module.eks.cluster_name
  }

  set {
    name = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.lb_controller_role.iam_role_arn
  }
}

resource "kubernetes_ingress_v1" "app_ingress" {
  metadata {
    
    name = "ph-clinic-app-ingress"
    
    annotations = {
      "alb.ingress.kubernetes.io/scheme"      = "internet-facing",
      "alb.ingress.kubernetes.io/target-type" = "ip",
    }

    labels = {
      "app.kubernetes.io/name"       = "app"
      "app.kubernetes.io/instance"   = "app"
      "app.kubernetes.io/version"    = "0.1"
      "app.kubernetes.io/component"  = "ingress"
      "app.kubernetes.io/part-of"    = "petclinic"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
  
  spec {
    ingress_class_name = "alb"

    default_backend {
      service {
        name = "ph-clinic-app-service"
        port {
          number = 8080
        }
      }
    }
  }
}