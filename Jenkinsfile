pipeline {
    agent any
    environment {
        ECR_URI = "<aws-account-id>.dkr.ecr.us-east-1.amazonaws.com/clients-api"  // account id removed for security, deleted after deployment
        IMAGE_TAG = "latest"
    }
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build') {
            steps {
                sh 'docker build -t clients-api:latest .'
            }
        }

        stage('Test') {  // optional test here
            steps {
                sh 'go test ./...'
            }
        }

        stage('Push to ECR') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'aws-ecr', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                    sh '''
                    aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_URI
                    docker tag clients-api:latest $ECR_URI:$IMAGE_TAG
                    docker push $ECR_URI:$IMAGE_TAG
                    '''
                }
            }
        }

        stage('Deploy to EKS') {
            steps {
                echo "This stage would apply the Kubernetes manifests:"
                echo "kubectl apply -f k8s/"
            }
        }
    }
}
