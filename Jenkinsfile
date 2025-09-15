pipeline {
  agent any

  environment {
    AWS_REGION = 'us-west-1'
    CLUSTER    = 'eks-demo-dipen'
    APP_NAME   = 'hello-web'
    PATH       = "/usr/local/bin:/usr/bin:/bin:/usr/sbin:${env.PATH}"
  }

  options { timestamps() }

  stages {
    stage('Checkout') {
      steps { checkout scm }
    }

    stage('Resolve AWS/ECR & Login') {
      steps {
        sh '''
          set -euxo pipefail
          ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
          echo "ACCOUNT_ID=$ACCOUNT_ID" > .build_vars
          echo "ECR_URI=${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${APP_NAME}" >> .build_vars

          aws ecr describe-repositories --repository-names ${APP_NAME} --region ${AWS_REGION} >/dev/null 2>&1 || \
            aws ecr create-repository --repository-name ${APP_NAME} --region ${AWS_REGION}

          # robust login
          for i in $(seq 1 5); do
            aws ecr get-login-password --region ${AWS_REGION} | \
              docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com && break || sleep 2
          done
        '''
      }
    }

    stage('Build & Smoke Test') {
      steps {
        sh '''
          set -euxo pipefail
          source .build_vars
          # tag with git short SHA if available, else BUILD_NUMBER
          GIT_SHA=$(git rev-parse --short=12 HEAD || echo "nosha")
          IMAGE_TAG=${GIT_SHA}-${BUILD_NUMBER}
          echo "IMAGE_TAG=${IMAGE_TAG}" >> .build_vars

          docker build -t ${APP_NAME}:${IMAGE_TAG} -t ${APP_NAME}:latest .

          # local smoke test
          docker run -d --rm --name smoke -p 3000:3000 ${APP_NAME}:${IMAGE_TAG}
          for i in $(seq 1 20); do curl -sf http://localhost:3000/ && break || sleep 1; done
          curl -sf http://localhost:3000/ | head -n 1
          docker rm -f smoke
        '''
      }
    }

    stage('Push to ECR') {
      steps {
        sh '''
          set -euxo pipefail
          source .build_vars
          docker tag ${APP_NAME}:${IMAGE_TAG} ${ECR_URI}:${IMAGE_TAG}
          docker tag ${APP_NAME}:${IMAGE_TAG} ${ECR_URI}:latest
          docker push ${ECR_URI}:${IMAGE_TAG}
          docker push ${ECR_URI}:latest
        '''
      }
    }

    stage('Configure kubectl') {
      steps {
        sh '''
          set -euxo pipefail
          aws eks update-kubeconfig --name ${CLUSTER} --region ${AWS_REGION}
          kubectl get nodes
        '''
      }
    }

    stage('Deploy to EKS (with rollback)') {
      steps {
        sh '''
          set -euxo pipefail
          source .build_vars

          # ensure namespace & apply manifests (image is placeholder; we patch next)
          kubectl get ns demo >/dev/null 2>&1 || kubectl create ns demo
          kubectl apply -f namespace.yaml
          kubectl apply -f deployment.yaml
          kubectl apply -f service.yaml

          # capture previous image (if any)
          PREV_IMG=$(kubectl -n demo get deploy/${APP_NAME} -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true)
          echo "Previous image: ${PREV_IMG:-<none>}"

          # set new image tag and roll out
          kubectl -n demo set image deploy/${APP_NAME} ${APP_NAME}=${ECR_URI}:${IMAGE_TAG}
          set +e
          kubectl -n demo rollout status deploy/${APP_NAME} --timeout=180s
          R=$?
          set -e

          if [ "$R" -ne 0 ]; then
            echo "❌ Rollout failed. Describing objects…"
            kubectl -n demo describe deploy/${APP_NAME} || true
            kubectl -n demo get pods -o wide || true
            kubectl -n demo describe pods -l app=${APP_NAME} || true

            if [ -n "${PREV_IMG}" ]; then
              echo "↩️  Rolling back to ${PREV_IMG}"
              kubectl -n demo set image deploy/${APP_NAME} ${APP_NAME}=${PREV_IMG}
              kubectl -n demo rollout status deploy/${APP_NAME} --timeout=180s || true
            fi
            exit 1
          fi

          # show service
          kubectl -n demo get svc ${APP_NAME} -o wide
        '''
      }
    }
  }

  post {
    failure {
      sh '''
        set +e
        kubectl -n demo describe deploy/${APP_NAME} || true
        kubectl -n demo get pods -o wide || true
        kubectl -n demo logs -l app=${APP_NAME} --tail=100 || true
      '''
    }
    always {
      sh 'docker image prune -f || true'
      archiveArtifacts artifacts: '.build_vars', fingerprint: true, onlyIfSuccessful: false
    }
  }
}
