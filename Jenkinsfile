pipeline {
  agent any

  environment {
    APP_NAME = "fcp-app"
    DOCKER_REGISTRY = "docker.io"
    DOCKER_REPO = "dkannaiy/fcp-app"
    DOCKER_TAG = "${env.BUILD_NUMBER}"
    AWS_REGION = "us-east-1"
    KUBE_CONFIG = "eks-kubeconfig"
    HELM_RELEASE = "fcp-app-release"
    HELM_CHART_PATH = "helm/fcp-app"
    EKS_NAMESPACE = "staging"
  }

  tools {
    nodejs "Node18"
  }

stages {
  stage('checkout') {
     steps {
       git branch: 'master', url:"https://github.com/deepakann/FilmCastPro.git"
     }
  }

  stage('Install Dependencies') {
     steps {
         sh 'npm ci'        
     }
  }

  stage('Build FilmCastPro Application') {
     steps {
         sh 'npm run build'
     }
  } 
  

  stage('Build Docker Image') {
     steps {
       script {
           dockerImage = docker.build("${DOCKER_REPO}:${DOCKER_TAG}", ".")
       }
     }
  }

  stage('Push Docker Image to Docker Hub Registry') {
      steps {
         script {
            // DockerHub login
             withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                 sh """
                    echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin $DOCKER_REGISTRY
                    docker push ${DOCKER_REPO}:${DOCKER_TAG}
                 """
            }
         }
      }
  }

  stage('Deploy to EKS Cluster using Helm') {
    steps {
        script {
           withCredentials ([
             file(credentialsId: "${KUBE_CONFIG}", variable: 'KUBECONFIG_PATH')
             string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
             string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY')
           ]) {
                sh '''
                  set -e

                  export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
                  export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
                  export AWS_DEFAULT_REGION=${AWS_REGION}
                  
                  echo "Setting up KubeConfig..."
                  cp $KUBECONFIG_PATH ./kubeconfig
                  chmod 600 ./kubeconfig
                  export KUBECONFIG=./kubeconfig

                  echo "Updating kubeconfig for EKS cluster..."
                  aws eks --region ${AWS_REGION} update-kubeconfig --name filmcastpro-eks-MquqUXuA --kubeconfig ./kubeconfig

                  echo "Testing cluster connectivity..."
                  kubectl get nodes

                  echo "Deploying Helm Chart..."
                  helm upgrade --install ${HELM_RELEASE} ${HELM_CHART_PATH} \
                     --namespace ${EKS_NAMESPACE} \
                     --create-namespace \
                     --set image.repository=${DOCKER_REPO} \
                     --set image.tag=${DOCKER_TAG} \
                     --wait --timeout 300s || \
                     (echo "Helm Deployment Failed. Rolling back.." &&\
                      helm rollback ${HELM_RELEASE} && exit 1)

                  echo "Verifying deployment..."
                  kubectl rollout status deployment/${APP_NAME} -n ${EKS_NAMESPACE} --timeout=300s
                '''
          }
        }  
      }          
    } 
  /* stage('Update Helm values and push to Git') {
    steps {
      script {
        sh '''
          sed -i "s|tag: .*|tag: ${DOCKER_TAG}|" ${HELM_CHART_PATH}/values.yaml
          git config --global user.email "deepakann77@gmail.com"
          git config --global user.name "deepakann"
          git add ${HELM_CHART_PATH}/values.yaml
          git commit -m "Update image tag to ${DOCKER_TAG} for release ${HELM_RELEASE}"
          git push origin master
        '''
      }
    }
  } */
  /* stage('Trigger ArgoCD Deployment') {
    steps {
      withCredentials([string(credentialsId: 'argocd-token', variable: 'ARGOCD_AUTH_TOKEN')]) {
        sh '''
          argocd login argocd-server.example.com --grpc-web --username admin --password $ARGOCD_AUTH_TOKEN --insecure
          argocd app sync ${APP_NAME} --grpc-web --timeout 600
          argocd app wait ${APP_NAME} --sync --health --timeout 600
        '''
      }   
    }
  } */ 
 }
}
