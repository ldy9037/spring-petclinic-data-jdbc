1. Maven을 수동으로 확인거나 스캐닝 작업을 하지 않아도 `gradle init` 명령어로 Maven으로 관리하던 의존성 대부분을 자동으로 가져올 수 있습니다. 
하지만 모든 의존성을 완벽하게 인식하는 것은 아니라서 일부 의존성은 수동으로 확인했습니다. 모든 의존성을 확인한 뒤 gradle 기본 템플릿을 복사해와서 현재 환경에 맞춘 뒤 의존성 부분만 추가해서 구성했습니다. (maven publish를 사용하지 않았습니다.)

Docker build를 위한 `dockerfile`의 경우 모범사례를 따라 Layer를 적용해서 구성하였습니다. Springboot 2.3.0부터는 build된 JAR 파일에 레이어 정보가 포함되는데 이 계층 정보를 사용해 이후 빌드 시 변경 가능성을 체크해 레이어를 분리할 수 있습니다. 즉, Docker의 Layer 캐싱 기능을 더 효과적으로 사용할 수 있게 됩니다.
```
# build/extracted에 build된 JAR에서 계층정보를 기반으로 레이어 분리 
RUN mkdir -p build/extracted && (java -Djarmode=layertools -jar build/libs/spring-petclinic-data-jdbc.jar extract --destination build/extracted)
```

또한 사용자 환경에 독립적으로 어플리케이션을 빌드하고 Docker image를 생성할 수 있도록 다단계 빌드를 구성하였습니다.

2. 시간 문제로 구성을 하지 못했습니다. 단순히 `/logs`에 적재만 한다고 하면 PV/PVC를 구성해서 해결했을 것 같습니다. 

3. `src/main/java/org/springframework/sample/petclinic/system/WelcomeController.java`에 health check용으로 `/healthcheck` API를 작성하였습니다. 단순 상태 검사용이기 때문에 Reponse body는 비워두고 상태값만 반환하도록 작성하였습니다.

4. Pod가 Terminating될 때 graceful하게 종료되도록 기본 30초의 유예기간을 부여합니다.Deployment template에 `termination_grace_period_seconds=30`을 명시해 30초 내로 중지되지 않으면 강제로 중지되도록 설정하였습니다. 
```
# infra/terraform/app.tf
resource "kubernetes_deployment" "app_deployment" {
        ...

        termination_grace_period_seconds = 30

        ...
}
```

5. deployment의 rolling update 옵션 중 `max_unavailable`과 `max_surge`값을 사용해 무중단으로 배포되도록 구성하였습니다. 기본적으로 pod replica 수는 3개로 `max_unavailable`을 1로 설정해 최소 활성 pod가 2개 이상이 되도록 구성하였고 `max_surge`를 0으로 설정해 기존 및 새 파드가 3개를 넘지 않도록 구성하였습니다. 
```
# infra/terraform/app.tf
resource "kubernetes_deployment" "app_deployment" {
    ...

    strategy {
      rolling_update {
        max_unavailable = 1
        max_surge = 0
      }
    }

    ...
}
```

6. deployment template에는 `security_context`라고 하는 파드 보안 속성을 제공하고 있습니다. 이 보안 속성 중 `run_as_non_root`와 `run_as_user` 속성을 사용해 root 제한 유효성 검증 및 컨테이너 프로세스를 실행할 UID를 설정할 수 있습니다. 
```
# infra/terraform/app.tf
resource "kubernetes_deployment" "app_deployment" {
        ...
        
        security_context {
          run_as_non_root = true
          run_as_user = 999  
        }

        ...
}
```

7. stateful-set을 사용하면 상태를 유지할 수 있는 파드를 구성할 수 있습니다. stateful-set으로 구성한 파드들은 재스케줄링 간에도 지속적으로 유지되는 식별자를 가지고 있어 파드들의 순서와 고유성을 보장합니다. 
데이터베이스의 경우 볼륨을 사용해 지속성을 제공해야하기 때문에 PV/PVC를 활용할 수 있습니다. 
```
# infra/terraform/database.tf
resource "kubernetes_stateful_set" "mysql_stateful_set" {
    ...

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

    ...

}
```

8. 어플리케이션에서 DB에 접근할 수 있도록 headless-service를 구성해줘야 합니다. `cluster_ip`를 `None`으로 지정해주면 headless-service를 구성할 수 있으며 DNS로 DB와 통신할 수 있게 됩니다. 
```
# infra/terraform/database.tf
resource "kubernetes_service" "mysql_service" {
    ...

    cluster_ip = "None"
    
    ...
}
``` 

9. AWS Controller를 구성해 AWS ALB로 Ingress를 구성하였습니다. 

10. namespace로 default를 사용하였습니다. 
11. 
#### 실행방법
- Cluster는 EKS로 구성하였습니다. 
- AWS 리소스 및 Manifest는 Terraform으로 구성하였습니다.  
1. Terraform으로 AWS 리소스 프로비저닝합니다.
```
terraform init
terraform validate
terraform plan
terraform apply
```

2. AWS 및 K8s Object 생성이 완료되면 어플리케이션 및 Docker Image를 빌드해 ECR에 푸쉬합니다. 
