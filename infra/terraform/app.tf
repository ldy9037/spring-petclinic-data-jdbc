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