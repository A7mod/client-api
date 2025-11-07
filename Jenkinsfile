pipeline {
    agent any

    environment {
        ECR_URI = "${env.AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/clients-api"
        ECR_REGION = "us-east-1"
        IMAGE_NAME = "clients-api"
        // Use git commit SHA for better traceability
        IMAGE_TAG = "${env.GIT_COMMIT?.take(8) ?: 'latest'}"
        BUILD_VERSION = "${env.BUILD_NUMBER}-${env.GIT_COMMIT?.take(8) ?: 'unknown'}"
        KUBERNETES_NAMESPACE = "${env.DEPLOY_ENV ?: 'production'}"
        SLACK_CHANNEL = "#deployments"
        APP_NAME = "clients-api"
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '30', daysToKeepStr: '30'))
        timestamps()
        timeout(time: 1, unit: 'HOURS')
        disableConcurrentBuilds()
        ansiColor('xterm')
    }

    parameters {
        choice(name: 'DEPLOY_ENV', choices: ['staging', 'production'], description: 'Deployment environment')
        booleanParam(name: 'SKIP_TESTS', defaultValue: false, description: 'Skip test execution')
        booleanParam(name: 'SKIP_SECURITY_SCAN', defaultValue: false, description: 'Skip security scan')
        string(name: 'KUBECTL_VERSION', defaultValue: 'v1.28.0', description: 'kubectl version to use')
    }

    stages {
        stage('Initialization') {
            steps {
                script {
                    echo "=========================================="
                    echo "Build Information"
                    echo "=========================================="
                    echo "Application: ${APP_NAME}"
                    echo "Build Number: ${env.BUILD_NUMBER}"
                    echo "Git Branch: ${env.GIT_BRANCH ?: 'N/A'}"
                    echo "Git Commit: ${env.GIT_COMMIT ?: 'N/A'}"
                    echo "Image Tag: ${IMAGE_TAG}"
                    echo "Build Version: ${BUILD_VERSION}"
                    echo "Environment: ${KUBERNETES_NAMESPACE}"
                    echo "=========================================="
                    
                    // Set dynamic environment variables
                    env.ECR_FULL_URI = "${ECR_URI}:${IMAGE_TAG}"
                    env.START_TIME = new Date().format('yyyy-MM-dd HH:mm:ss')
                }
            }
        }

        stage('Checkout') {
            steps {
                script {
                    try {
                        checkout scm
                        sh 'git log -1 --pretty=format:"%h - %an, %ar : %s"'
                    } catch (Exception e) {
                        error "Failed to checkout source code: ${e.message}"
                    }
                }
            }
        }

        stage('Code Quality & Linting') {
            steps {
                script {
                    echo "Running Go linting and formatting checks..."
                    sh '''
                        # Check if gofmt would make changes
                        if [ -n "$(gofmt -l .)" ]; then
                            echo "The following files are not formatted:"
                            gofmt -l .
                            exit 1
                        fi
                        
                        # Run go vet
                        go vet ./...
                        
                        # Optional: Run golangci-lint if available
                        if command -v golangci-lint &> /dev/null; then
                            golangci-lint run --timeout 5m
                        else
                            echo "golangci-lint not found, skipping..."
                        fi
                    '''
                }
            }
        }

        stage('Test') {
            when {
                expression { params.SKIP_TESTS == false }
            }
            steps {
                script {
                    echo "Running unit tests..."
                    sh '''
                        # Run tests with coverage
                        go test -v -race -coverprofile=coverage.out -covermode=atomic ./...
                        
                        # Generate coverage report
                        go tool cover -func=coverage.out
                        
                        # Optional: Check coverage threshold
                        COVERAGE=$(go tool cover -func=coverage.out | grep total | awk '{print $3}' | sed 's/%//')
                        echo "Total coverage: ${COVERAGE}%"
                        
                        # Fail if coverage is below threshold (e.g., 70%)
                        THRESHOLD=70
                        if (( $(echo "$COVERAGE < $THRESHOLD" | bc -l) )); then
                            echo "Coverage ${COVERAGE}% is below threshold ${THRESHOLD}%"
                            exit 1
                        fi
                    '''
                }
            }
            post {
                always {
                    // Publish test results if using gotestsum or similar
                    sh 'echo "Test results published"'
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    echo "Building Docker image..."
                    sh '''
                        docker build \
                            --build-arg BUILD_VERSION=${BUILD_VERSION} \
                            --build-arg GIT_COMMIT=${GIT_COMMIT} \
                            --build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
                            -t ${IMAGE_NAME}:${IMAGE_TAG} \
                            -t ${IMAGE_NAME}:latest \
                            --no-cache \
                            .
                        
                        # Verify image was created
                        docker images | grep ${IMAGE_NAME}
                    '''
                }
            }
        }

        stage('Security Scan') {
            when {
                expression { params.SKIP_SECURITY_SCAN == false }
            }
            steps {
                script {
                    echo "Scanning Docker image for vulnerabilities..."
                    sh '''
                        # Using Trivy for vulnerability scanning
                        # Install trivy if not available
                        if ! command -v trivy &> /dev/null; then
                            echo "Installing Trivy..."
                            wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | apt-key add -
                            echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | tee -a /etc/apt/sources.list.d/trivy.list
                            apt-get update
                            apt-get install -y trivy
                        fi
                        
                        # Run Trivy scan
                        trivy image \
                            --severity HIGH,CRITICAL \
                            --exit-code 1 \
                            --no-progress \
                            --format table \
                            ${IMAGE_NAME}:${IMAGE_TAG} || {
                            echo "Critical vulnerabilities found! Review and fix before deploying to production."
                            if [ "${DEPLOY_ENV}" = "production" ]; then
                                exit 1
                            else
                                echo "Continuing despite vulnerabilities in non-production environment..."
                            fi
                        }
                    '''
                }
            }
        }

        stage('Push to ECR') {
            steps {
                script {
                    echo "Authenticating with ECR and pushing image..."
                    withCredentials([usernamePassword(
                        credentialsId: 'aws-ecr',
                        usernameVariable: 'AWS_ACCESS_KEY_ID',
                        passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                    )]) {
                        sh '''
                            set -e
                            
                            # Login to ECR
                            aws ecr get-login-password --region ${ECR_REGION} | \
                                docker login --username AWS --password-stdin ${ECR_URI}
                            
                            # Tag images
                            docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${ECR_URI}:${IMAGE_TAG}
                            docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${ECR_URI}:build-${BUILD_NUMBER}
                            
                            # Push with retries
                            MAX_RETRIES=3
                            RETRY_COUNT=0
                            
                            while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
                                if docker push ${ECR_URI}:${IMAGE_TAG} && \
                                   docker push ${ECR_URI}:build-${BUILD_NUMBER}; then
                                    echo "Successfully pushed image to ECR"
                                    break
                                else
                                    RETRY_COUNT=$((RETRY_COUNT+1))
                                    echo "Push failed. Retry $RETRY_COUNT of $MAX_RETRIES..."
                                    sleep 5
                                fi
                            done
                            
                            if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
                                echo "Failed to push image after $MAX_RETRIES attempts"
                                exit 1
                            fi
                            
                            # Tag and push environment-specific tag
                            docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${ECR_URI}:${DEPLOY_ENV}-latest
                            docker push ${ECR_URI}:${DEPLOY_ENV}-latest
                            
                            echo "Image pushed successfully:"
                            echo "  - ${ECR_URI}:${IMAGE_TAG}"
                            echo "  - ${ECR_URI}:build-${BUILD_NUMBER}"
                            echo "  - ${ECR_URI}:${DEPLOY_ENV}-latest"
                        '''
                    }
                }
            }
        }

        stage('Update Kubernetes Manifests') {
            steps {
                script {
                    echo "Updating Kubernetes manifests with new image tag..."
                    sh '''
                        # Update image tag in Kubernetes manifests
                        if [ -d "k8s" ]; then
                            # Create a temporary directory for updated manifests
                            mkdir -p k8s/generated
                            
                            # Update deployment manifest with new image
                            for file in k8s/.yaml k8s/.yml; do
                                if [ -f "$file" ]; then
                                    sed "s|image:.clients-api.|image: ${ECR_URI}:${IMAGE_TAG}|g" "$file" > "k8s/generated/$(basename $file)"
                                fi
                            done
                            
                            echo "Manifests updated in k8s/generated/"
                            ls -la k8s/generated/
                        else
                            echo "Warning: k8s directory not found"
                        fi
                    '''
                }
            }
        }

        stage('Deploy to EKS - Staging') {
            when {
                expression { params.DEPLOY_ENV == 'staging' }
            }
            steps {
                script {
                    echo "Deploying to EKS Staging environment..."
                    deployToKubernetes('staging')
                }
            }
        }

        stage('Deploy to EKS - Production') {
            when {
                expression { params.DEPLOY_ENV == 'production' }
            }
            steps {
                script {
                    // Add manual approval for production deployments
                    timeout(time: 15, unit: 'MINUTES') {
                        input message: 'Deploy to Production?',
                              ok: 'Deploy',
                              submitter: 'admin,devops-team',
                              submitterParameter: 'APPROVED_BY'
                    }
                    
                    echo "Deploying to EKS Production environment..."
                    deployToKubernetes('production')
                }
            }
        }

        stage('Health Check') {
            steps {
                script {
                    echo "Performing health checks..."
                    sh '''
                        # Wait for deployment to be ready
                        kubectl rollout status deployment/${APP_NAME} \
                            -n ${KUBERNETES_NAMESPACE} \
                            --timeout=5m || {
                            echo "Deployment failed to become ready"
                            exit 1
                        }
                        
                        # Get pod status
                        kubectl get pods -n ${KUBERNETES_NAMESPACE} -l app=${APP_NAME}
                        
                        # Optional: Run smoke tests
                        echo "Running smoke tests..."
                        # Add your smoke test commands here
                    '''
                }
            }
        }

        stage('Tag Release') {
            when {
                expression { params.DEPLOY_ENV == 'production' }
            }
            steps {
                script {
                    echo "Tagging release in Git..."
                    sh '''
                        git tag -a v${BUILD_VERSION} -m "Release ${BUILD_VERSION} - Build ${BUILD_NUMBER}"
                        git push origin v${BUILD_VERSION} || echo "Failed to push tag, continuing..."
                    '''
                }
            }
        }
    }

    post {
        always {
            script {
                env.END_TIME = new Date().format('yyyy-MM-dd HH:mm:ss')
                echo "Build finished at: ${env.END_TIME}"
                
                // Cleanup
                sh '''
                    # Remove unused Docker images to save space
                    docker image prune -f --filter "until=24h" || true
                    
                    # Cleanup temporary files
                    rm -rf k8s/generated || true
                '''
            }
        }
        
        success {
            script {
                echo "✅ Pipeline completed successfully!"
                
                // Send success notification
                notifySlack(
                    'good',
                    "✅ Deployment Successful",
                    """
                    Application: ${APP_NAME}
                    Environment: ${KUBERNETES_NAMESPACE}
                    Build: #${env.BUILD_NUMBER}
                    Image Tag: ${IMAGE_TAG}
                    Duration: ${currentBuild.durationString}
                    Started by: ${env.BUILD_USER ?: 'Jenkins'}
                    """
                )
            }
        }
        
        failure {
            script {
                echo "❌ Pipeline failed!"
                
                // Send failure notification
                notifySlack(
                    'danger',
                    "❌ Deployment Failed",
                    """
                    Application: ${APP_NAME}
                    Environment: ${KUBERNETES_NAMESPACE}
                    Build: #${env.BUILD_NUMBER}
                    Stage: ${env.STAGE_NAME}
                    Error: Check console output for details
                    Build URL: ${env.BUILD_URL}
                    """
                )
                
                // Optional: Create incident ticket
                echo "Consider creating an incident ticket for investigation"
            }
        }
        
        unstable {
            script {
                notifySlack(
                    'warning',
                    "⚠ Build Unstable",
                    """
                    Application: ${APP_NAME}
                    Build: #${env.BUILD_NUMBER}
                    Status: Unstable - requires attention
                    """
                )
            }
        }
        
        aborted {
            script {
                notifySlack(
                    'warning',
                    "🛑 Build Aborted",
                    """
                    Application: ${APP_NAME}
                    Build: #${env.BUILD_NUMBER}
                    Status: Manually aborted
                    """
                )
            }
        }
    }
}

// Helper function for Kubernetes deployment
def deployToKubernetes(environment) {
    withCredentials([usernamePassword(
        credentialsId: 'aws-ecr',
        usernameVariable: 'AWS_ACCESS_KEY_ID',
        passwordVariable: 'AWS_SECRET_ACCESS_KEY'
    )]) {
        sh """
            set -e
            
            # Configure kubectl
            aws eks update-kubeconfig \
                --region ${ECR_REGION} \
                --name ${environment}-cluster
            
            # Verify cluster connectivity
            kubectl cluster-info
            kubectl get nodes
            
            # Create namespace if it doesn't exist
            kubectl create namespace ${environment} --dry-run=client -o yaml | kubectl apply -f -
            
            # Create or update image pull secret for ECR
            kubectl create secret docker-registry ecr-registry-secret \
                --docker-server=${ECR_URI} \
                --docker-username=AWS \
                --docker-password=\$(aws ecr get-login-password --region ${ECR_REGION}) \
                --namespace=${environment} \
                --dry-run=client -o yaml | kubectl apply -f -
            
            # Apply Kubernetes manifests
            if [ -d "k8s/generated" ]; then
                kubectl apply -f k8s/generated/ -n ${environment}
            else
                echo "Error: k8s/generated directory not found"
                exit 1
            fi
            
            # Set image for deployment (ensures latest image is used)
            kubectl set image deployment/${APP_NAME} \
                ${APP_NAME}=${ECR_URI}:${IMAGE_TAG} \
                -n ${environment} \
                --record
            
            # Annotate deployment with build info
            kubectl annotate deployment/${APP_NAME} \
                kubernetes.io/change-cause="Build ${BUILD_NUMBER} - ${GIT_COMMIT}" \
                -n ${environment} \
                --overwrite
            
            echo "Deployment initiated successfully"
        """
    }
}

// Helper function for Slack notifications
def notifySlack(color, title, message) {
    try {
        // Using Slack plugin
        slackSend(
            color: color,
            channel: env.SLACK_CHANNEL,
            message: "${title}\n${message}",
            tokenCredentialId: 'slack-token'
        )
    } catch (Exception e) {
        echo "Failed to send Slack notification: ${e.message}"
        echo "Notification content: ${title} - ${message}"
    }
}