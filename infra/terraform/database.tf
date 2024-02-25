locals {
  mysql_secret = jsondecode(file("${path.module}/secrets/mysql.json"))
}

resource "kubernetes_secret" "mysql_secret" {
  metadata {
    labels = {
      "app.kubernetes.io/name"       = "mysql"
      "app.kubernetes.io/version"    = "0.1"
      "app.kubernetes.io/component"  = "secret"
      "app.kubernetes.io/part-of"    = "petclinic"
      "app.kubernetes.io/managed-by" = "terraform"
    }

    name = "ph-clinic-mysql-secret"
  }

  data = {
    password = local.mysql_secret.password
  }

  type = "kubernetes.io/basic-auth"
}

resource "kubernetes_stateful_set" "mysql_stateful_set" {
  metadata {
    labels = {
      "app.kubernetes.io/name"       = "mysql"
      "app.kubernetes.io/version"    = "8.0"
      "app.kubernetes.io/component"  = "stateful-set"
      "app.kubernetes.io/part-of"    = "petclinic"
      "app.kubernetes.io/managed-by" = "terraform"
    }

    name = "ph-clinic-mysql-stateful-set"
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        "app.kubernetes.io/name"      = "mysql"
        "app.kubernetes.io/instance"  = "mysql"
        "app.kubernetes.io/component" = "database"
      }
    }

    service_name = "ph-clinic-mysql-service"

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"       = "mysql"
          "app.kubernetes.io/instance"   = "mysql"
          "app.kubernetes.io/version"    = "8.0"
          "app.kubernetes.io/component"  = "database"
          "app.kubernetes.io/part-of"    = "petclinic"
          "app.kubernetes.io/managed-by" = "terraform"
        }

        annotations = {}
      }

      spec {
        container {
          name              = "mysql"
          image             = "public.ecr.aws/docker/library/mysql:8.0"
          image_pull_policy = "IfNotPresent"

          env {
            name = "MYSQL_ROOT_PASSWORD"

            value_from {
              secret_key_ref {
                name = "ph-clinic-mysql-secret"
                key  = "password"
              }
            }
          }

          env {
            name  = "MYSQL_DATABASE"
            value = "petclinic"
          }

          env {
            name = "MYSQL_USER"
            value = "petclinic"
          }

          env {
            name = "MYSQL_PASSWORD"

            value_from {
              secret_key_ref {
                name = "ph-clinic-mysql-secret"
                key  = "password"
              }
            }
          }

          port {
            name           = "mysql"
            container_port = 3306
            protocol       = "TCP"
          }

          volume_mount {
            name       = "ph-clinic-mysql-data"
            mount_path = "/var/lib/mysql"
          }
        }
      }
    }

    volume_claim_template {
      metadata {
        name = "ph-clinic-mysql-data"
      }

      spec {
        access_modes       = ["ReadWriteOnce"]
        storage_class_name = "gp2"

        resources {
          requests = {
            storage = "10Gi"
          }
        }
      }
    }
  }
}


resource "kubernetes_service" "mysql_service" {
  metadata {
    labels = {
      "app.kubernetes.io/name"          = "mysql"
      "app.kubernetes.io/instance"      = "mysql"
      "app.kubernetes.io/version"       = "0.1"
      "app.kubernetes.io/component"     = "service"
      "app.kubernetes.io/part-of"       = "petclinic"
      "app.kubernetes.io/managed-by"    = "terraform"
    }

    name = "ph-clinic-mysql-service"
  }
  spec {
    selector = {
      "app.kubernetes.io/name" = kubernetes_stateful_set.mysql_stateful_set.spec.0.template.0.metadata.0.labels["app.kubernetes.io/name"]
      "app.kubernetes.io/component"  = kubernetes_stateful_set.mysql_stateful_set.spec.0.template.0.metadata.0.labels["app.kubernetes.io/component"]
    }

    port {
      port        = 3306
    }
    cluster_ip = "None"
  }
}