pipeline {
    agent any

    environment {
        APP_IMAGE = 'mi-app:latest'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build') {
            steps {
                sh 'mvn -B clean package -DskipTests'
            }
        }

        stage('Docker Build') {
            steps {
                sh 'docker build -t ${APP_IMAGE} .'
            }
        }

        stage('Test') {
            steps {
                sh '''
                    docker rm -f mi-app-test || true
                    docker run -d --name mi-app-test -p 8081:8080 ${APP_IMAGE}
                    sleep 15
                    docker logs mi-app-test | grep "Started CicdDemoApplication"
                    docker rm -f mi-app-test
                '''
            }
        }
    }

    post {
        always {
            sh 'docker rm -f mi-app-test || true'
            junit allowEmptyResults: true, testResults: 'target/surefire-reports/*.xml'
            archiveArtifacts allowEmptyArchive: true, artifacts: 'target/*.jar'
        }
    }
}
