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
        container {
          name              = "app"
          image             = "901371017570.dkr.ecr.ap-northeast-2.amazonaws.com/ph-petclinic-common-ecr-1:latest"

          liveness_probe {
            http_get {
              path = "/"
              port = 8080
            }
            
            failure_threshold = 5
            initial_delay_seconds = 30
            period_seconds        = 5
          }

          volume_mount {
            name = "ph-petclinic-log-volume"
            mount_path = "/var/log/container"
          }
        }

        container {
          name = "log-fetcher"
          image = "public.ecr.aws/docker/library/busybox:1.35.0"
          tty = true
          args = [ "/bin/bash", "-c", "'sleep 60 && tail -n+1 -f /logs/app.log'" ]

          volume_mount {
            name = "ph-petclinic-log-volume"
            mount_path = "/logs"
          }
        } 

        volume {
          name = "ph-petclinic-log-volume"
          empty_dir {
            
          }
        }
      }
    }
  }
}