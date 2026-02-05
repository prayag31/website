pipeline {
  agent any

  parameters {
    booleanParam(
      name: 'FORCE_DEPLOY',
      defaultValue: true,
      description: 'Force deployment even if today is not the 25th (for testing only)'
    )
  }

  environment {
    AWS_REGION        = 'ap-south-1'
    CODEBUILD_PROJECT = 'Capstone-project'
    DOCKER_IMAGE      = 'prayag31/website'

    // K8s access
    K8S_MASTER_IP     = '3.108.10.150'     // public IP (SSH only)
    KUBECONFIG        = "${WORKSPACE}/kubeconfig"
    NAMESPACE         = 'prod'
    DEPLOYMENT_NAME  = 'website'
    CONTAINER_NAME   = 'website'
  }

  stages {

    stage('Checkout') {
      steps {
        checkout scm
        sh '''
          git rev-parse --short HEAD > .gitshort
          echo "Commit: $(cat .gitshort)"
        '''
        script {
          env.IMAGE_TAG = readFile('.gitshort').trim()
        }
      }
    }

    stage('Trigger CodeBuild (Build & Push Image)') {
      steps {
        sh '''
          set -e
          echo "Starting CodeBuild project: ${CODEBUILD_PROJECT}"

          BUILD_ID=$(aws codebuild start-build \
            --region ${AWS_REGION} \
            --project-name ${CODEBUILD_PROJECT} \
            --query 'build.id' \
            --output text)

          echo "CodeBuild ID: $BUILD_ID"
          echo "Waiting for CodeBuild to finish..."

          while true; do
            STATUS=$(aws codebuild batch-get-builds \
              --region ${AWS_REGION} \
              --ids "$BUILD_ID" \
              --query 'builds[0].buildStatus' \
              --output text)

            echo "Status: $STATUS"

            if [ "$STATUS" = "SUCCEEDED" ]; then
              echo "CodeBuild succeeded"
              break
            fi

            if [ "$STATUS" = "FAILED" ] || [ "$STATUS" = "FAULT" ] || \
               [ "$STATUS" = "STOPPED" ] || [ "$STATUS" = "TIMED_OUT" ]; then
              echo "CodeBuild failed"
              exit 1
            fi

            sleep 10
          done
        '''
      }
    }

    stage('Fetch kubeconfig from Master') {
      steps {
        sshagent(credentials: ['k8s-master-ssh']) {
          sh '''
            set -e
            rm -f ${KUBECONFIG}
            ssh -o StrictHostKeyChecking=no ubuntu@${K8S_MASTER_IP} \
              'cat /home/ubuntu/.kube/config' > ${KUBECONFIG}
            chmod 600 ${KUBECONFIG}
            kubectl --kubeconfig ${KUBECONFIG} get nodes
          '''
        }
      }
    }

    stage('Deploy to Kubernetes (25th rule)') {
      steps {
        sh '''
          set -e
          DAY=$(date +%d)
          echo "Day of month: $DAY"

          if [ "$DAY" != "25" ] && [ "${FORCE_DEPLOY}" != "true" ]; then
            echo "Not 25th and FORCE_DEPLOY=false → skipping deployment"
            exit 0
          fi

          IMAGE="${DOCKER_IMAGE}:${IMAGE_TAG}"
          echo "Deploying image: $IMAGE"

          kubectl --kubeconfig ${KUBECONFIG} apply -f k8s/namespace.yaml || true
          kubectl --kubeconfig ${KUBECONFIG} apply -f k8s/deployment.yaml
          kubectl --kubeconfig ${KUBECONFIG} apply -f k8s/service.yaml

          kubectl --kubeconfig ${KUBECONFIG} -n ${NAMESPACE} \
            set image deployment/${DEPLOYMENT_NAME} \
            ${CONTAINER_NAME}=${IMAGE}

          kubectl --kubeconfig ${KUBECONFIG} -n ${NAMESPACE} \
            rollout status deployment/${DEPLOYMENT_NAME}

          kubectl --kubeconfig ${KUBECONFIG} -n ${NAMESPACE} get pods -o wide
        '''
      }
    }
  }

  post {
    success {
      echo 'Pipeline completed successfully'
    }
    failure {
      echo 'Pipeline failed'
    }
  }
}
