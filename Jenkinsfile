pipeline {
    agent any

    environment {
        DOCKER_REGISTRY = "docker.io"
        DOCKER_REPO = "vimalathanga/filmcastpro-frontend"
        DOCKER_IMAGE_TAG = "${env.BUILD_NUMBER}"

        SONAR_HOST_URL = 'https://sonarcloud.io'
        SONAR_TOKEN = credentials('sonarcloud-token')

        TEAMS_WEBHOOK_ID = 'teams-webhook'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Install Dependencies') {
            steps {
                dir('sample-react-app') {
                    sh 'npm ci'
                }    
            }
        }      
        
        stage('Run Unit Test') {
            steps {
                dir('sample-react-app') {
                    sh 'npm test'
                }
            }
        }

        stage('Build React App') {
            steps {
                dir('sample-react-app') {
                    sh 'npm run build'
                }
            }
        }   

        stage('SonarQube Scanning') {
            steps {
                withSonarQubeEnv('SonarCloud') {
                    dir('sample-react-app') {
                        sh '''
                            echo "Running SonarQube scan..."
                            npx sonar-scanner \
                              -Dproject.settings=sonar-project.properties \
                              -Dsonar.host.url=${SONAR_HOST_URL} \
                              -Dsonar.organization=vimalathanga \
                              -Dsonar.token=${SONAR_TOKEN}
                        '''
                    }
                }
            }
        }
                   
        stage('Sonar Quality Gate') {
            steps {
                timeout(time: 1, unit: 'MINUTES') {
                    script {
                        def qg = waitForQualityGate()
                        if (qg.status != 'OK') {
                            error "❌ Quality Gate failed: ${qg.status}"
                        } else {
                            echo "✅ Quality Gate passed for build ${BUILD_NUMBER}"
                        }
                    }    
                }    
            }
        }

        stage('Trivy Filesystem Scan') {
            steps {
                sh """
                    echo "🔍 Running Trivy FS Scan..."
                    trivy fs --exit-code 0 --severity HIGH,CRITICAL ./sample-react-app
                """
            }
        }
    
        stage('Create Docker Image') {
            steps {
                script {
                    docker.build(
                        "${DOCKER_REPO}:${DOCKER_IMAGE_TAG}",
                        "-f Dockerfile ."
                    )
                }
            }
        }

        stage('Container Image Scanning - Trivy') {
            steps {
                sh """
                    trivy image --exit-code 0 --severity HIGH,CRITICAL ${DOCKER_REPO}:${DOCKER_IMAGE_TAG}
                """
            }
        }

        stage('Push Docker Image to Registry') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'vimalathanga', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                    sh """
                        echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin $DOCKER_REGISTRY
                        docker push ${DOCKER_REPO}:${DOCKER_IMAGE_TAG}
                    """
                }
            }
        }

        stage('Update GitOps Repo for ArgoCD') {
            steps {
                script {
                    withCredentials([usernamePassword(credentialsId: '7a747fa5-4c84-4771-89db-8190b6b9a1c4', usernameVariable: 'GIT_USER', passwordVariable: 'GIT_PASS')]) {
                        sh '''
                            git config --global user.email "vimalathangs203@gmail.com"
                            git config --global user.name "vimalathanga"

                            if [ -d FilmCastPro_Deepa ]; then rm -rf FilmCastPro_Deepa; fi
                            git clone https://$GIT_USER:$GIT_PASS@github.com/vimalathanga/FilmCastPro_Deepa.git
                            cd FilmCastPro_Deepa/helm/filmcastpro-frontend

                            sed -i "s|tag:.*|tag: ${BUILD_NUMBER}|" values.yaml
                            git add values.yaml
                            git commit -m "Updated image tag to ${BUILD_NUMBER}"
                            git push https://$GIT_USER:$GIT_PASS@github.com/vimalathanga/FilmCastPro_Deepa.git
                        '''
                    }
                }
            }
        }
    }

    post {
        success {
            withCredentials([string(credentialsId: "${TEAMS_WEBHOOK_ID}", variable: 'TEAMS_WEBHOOK')]) {
                sh """
                    curl -H 'Content-Type: application/json' \
                        -d '{"text":"✅ Build #${env.BUILD_NUMBER} succeeded for ${env.JOB_NAME}"}' \
                        $TEAMS_WEBHOOK
                """
            }
        }
        failure {
            withCredentials([string(credentialsId: "${TEAMS_WEBHOOK_ID}", variable: 'TEAMS_WEBHOOK')]) {
                sh """
                    curl -H 'Content-Type: application/json' \
                        -d '{"text":"❌ Build #${env.BUILD_NUMBER} failed for ${env.JOB_NAME}"}' \
                        $TEAMS_WEBHOOK
                """
            }
        }
    }
}
