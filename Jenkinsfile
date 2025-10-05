pipeline {
    agent any

    environment {
        // ----- Docker Hub configuration -----
        DOCKER_REGISTRY = "docker.io"
        DOCKER_REPO = "vimalathanga/filmcastpro-frontend"
        DOCKER_IMAGE_TAG = "${env.BUILD_NUMBER}"

        // ----- SonarQube -----
        SONAR_HOST_URL = 'https://sonarcloud.io'
        SONAR_TOKEN = credentials('sonarcloud-token')

        // ----- Teams Webhook -----
        TEAMS_WEBHOOK_ID = 'teams-webhook'
    }

    tools {
        // Node.js tool in Jenkins (Manage Jenkins -> Global Tool Configuration)
        nodejs "Node18"
    }

    stages {

        /* -----------------------------
         *   SOURCE + BUILD PHASE
         * ----------------------------- */

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

        stage('Run Unit Tests') {
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

        /* -----------------------------
         *   CODE QUALITY & SECURITY
         * ----------------------------- */

        stage('SonarQube Scan') {
            steps {
                withSonarQubeEnv('SonarCloud') {
                    dir('sample-react-app') {
                        sh '''
                            echo "🔍 Running SonarQube scan..."
                            npx sonar-scanner \
                              -Dproject.settings=sonar-project.properties \
                              -Dsonar.host.url=${SONAR_HOST_URL} \
                              -Dsonar.organization=deepakann \
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
                            echo "✅ Quality Gate passed for build #${BUILD_NUMBER}"
                        }
                    }
                }
            }
        }

        stage('Trivy Filesystem Scan') {
            steps {
                sh '''
                    echo "🔒 Running Trivy FS Scan..."
                    trivy fs --exit-code 0 --severity HIGH,CRITICAL ./sample-react-app
                '''
            }
        }

        /* -----------------------------
         *   CONTAINERIZATION PHASE
         * ----------------------------- */

        stage('Build Docker Image') {
            steps {
                sh '''
                    echo "🐳 Building Docker Image..."
                    docker build -t ${DOCKER_REPO}:${DOCKER_IMAGE_TAG} -f Dockerfile .
                '''
            }
        }

        stage('Trivy Image Scan') {
            steps {
                sh '''
                    echo "🔍 Scanning Docker Image for vulnerabilities..."
                    trivy image --exit-code 0 --severity HIGH,CRITICAL ${DOCKER_REPO}:${DOCKER_IMAGE_TAG}
                '''
            }
        }

        stage('Push Docker Image to Registry') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'vimalathanga', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                    sh '''
                        echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin $DOCKER_REGISTRY
                        docker push ${DOCKER_REPO}:${DOCKER_IMAGE_TAG}
                    '''
                }
            }
        }

        /* -----------------------------
         *   GITOPS UPDATE FOR ARGOCd
         * ----------------------------- */

       stage('Update GitOps Repo for ArgoCD') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'github-creds', usernameVariable: 'GIT_USER', passwordVariable: 'GIT_TOKEN')]) {
                    sh '''
                        echo "🌀 Updating Helm values.yaml for ArgoCD..."
                        git config --global user.email "vimalathangs203@gmail.com"
                        git config --global user.name "vimalathanga"

                        rm -rf FilmCastPro_Deepa
                        git clone https://${GIT_USER}:${GIT_TOKEN}@github.com/vimalathanga/FilmCastPro_Deepa.git
                        cd FilmCastPro_Deepa/helm/filmcastpro-frontend

                            sed -i "s|tag:.*|tag: \\"${BUILD_NUMBER}\\"|" values.yaml

                            git add values.yaml
                            git commit -m "Updated image tag to ${BUILD_NUMBER}"
                            git push origin feature/helm-argocd
                            '''
        }
    }
}


    /* -----------------------------
     *   POST-BUILD NOTIFICATIONS
     * ----------------------------- */

    post {
        success {
            withCredentials([string(credentialsId: "${TEAMS_WEBHOOK_ID}", variable: 'TEAMS_WEBHOOK')]) {
                sh """
                    curl -H 'Content-Type: application/json' \
                      -d '{"text":"✅ Jenkins Build #${BUILD_NUMBER} succeeded for ${JOB_NAME} and ArgoCD will sync automatically."}' \
                      $TEAMS_WEBHOOK
                """
            }
        }
        failure {
            withCredentials([string(credentialsId: "${TEAMS_WEBHOOK_ID}", variable: 'TEAMS_WEBHOOK')]) {
                sh """
                    curl -H 'Content-Type: application/json' \
                      -d '{"text":"❌ Jenkins Build #${BUILD_NUMBER} failed for ${JOB_NAME}. Please check logs."}' \
                      $TEAMS_WEBHOOK
                """
            }
        }
    }
}
