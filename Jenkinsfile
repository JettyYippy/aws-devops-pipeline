pipeline {
    agent any
    
    environment {
        // REQUIRED: Change this to your actual Docker Hub username!
        DOCKERHUB_USER = 'jettyyippy' 
        APP_NAME = 'devops-demo-app'
    }
    
    stages {
        stage('Cleanup') {
            steps {
                echo 'Cleaning up old images...'
                // Cleans up unused Docker data on the Jenkins server to save disk space
                sh "docker system prune -f"
            }
        }
        
        stage('Build Docker Image') {
            steps {
                echo 'Building the Docker image...'
                // Builds the container using the Dockerfile located in the /app folder
                sh "docker build -t ${DOCKERHUB_USER}/${APP_NAME}:latest ./app"
            }
        }
        
        stage('Push to DockerHub') {
            steps {
                echo 'Pushing image to Docker Hub...'
                // Authenticates and uploads the image to your central registry
                withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', passwordVariable: 'PASS', usernameVariable: 'USER')]) {
                    sh "echo ${PASS} | docker login -u ${USER} --password-stdin"
                    sh "docker push ${DOCKERHUB_USER}/${APP_NAME}:latest"
                }
            }
        }
        
        stage('Deploy to K3s Cluster') {
            steps {
                echo 'Deploying to Kubernetes...'
                // Communicates with the K3s server via public IP while skipping TLS verification
                withCredentials([file(credentialsId: 'k8s-config', variable: 'KUBECONFIG')]) {
                    sh """
                    kubectl --kubeconfig=${KUBECONFIG} \
                            --server=https://13.223.243.29:6443 \
                            --insecure-skip-tls-verify=true \
                            apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${APP_NAME}
spec:
  replicas: 2
  selector:
    matchLabels:
      app: ${APP_NAME}
  template:
    metadata:
      labels:
        app: ${APP_NAME}
    spec:
      containers:
      - name: ${APP_NAME}
        image: ${DOCKERHUB_USER}/${APP_NAME}:latest
        ports:
        - containerPort: 5000
---
apiVersion: v1
kind: Service
metadata:
  name: ${APP_NAME}-service
spec:
  type: NodePort
  selector:
    app: ${APP_NAME}
  ports:
    - protocol: TCP
      port: 80
      targetPort: 5000
      nodePort: 30001
EOF
                    """
                }
            }
        }
    }
    
    post {
        success {
            echo 'Pipeline completed successfully! App is live at http://13.223.243.29:30001'
        }
        failure {
            echo 'Pipeline failed. Check the Console Output logs for debugging.'
        }
    }
}
