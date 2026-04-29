pipeline {
    agent any

    environment {
        APP_IMAGE = 'mi-app:latest'
        APP_CONTAINER = 'mi-app'
        SONAR_HOST_URL = 'http://sonarqube:9000'
        SONAR_TOKEN = credentials('sonar-token')
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build & Test') {
            steps {
                sh 'mvn -B clean package -Djacoco.skip=true -Dgroups=UnitTest,IntegrationTest'
            }
        }

        stage('Static Analysis (SonarQube)') {
            steps {
                sh 'mvn -B sonar:sonar -Dsonar.projectKey=mi-app -Dsonar.host.url=${SONAR_HOST_URL} -Dsonar.login=${SONAR_TOKEN}'
            }
        }

        stage('Container Security Scan (Trivy)') {
            steps {
                sh 'docker build -t ${APP_IMAGE} .'
                sh 'docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v trivy_cache:/root/.cache/trivy aquasec/trivy:latest image --scanners vuln ${APP_IMAGE}'
            }
        }

        stage('Deploy') {
            when {
                anyOf {
                    branch 'main'
                    branch 'master'
                }
            }
            steps {
                sh '''
                    docker rm -f ${APP_CONTAINER} || true
                    docker run -d --name ${APP_CONTAINER} -p 8081:8080 ${APP_IMAGE}
                '''
            }
        }

        stage('Validate') {
            steps {
                sh '''
                    sleep 15
                    docker logs ${APP_CONTAINER} | grep "Started CicdDemoApplication"
                '''
            }
        }
    }

    post {
        always {
            echo 'Limpiando entorno...'
            junit allowEmptyResults: true, testResults: 'target/surefire-reports/*.xml'
            archiveArtifacts allowEmptyArchive: true, artifacts: 'target/*.jar'
            cleanWs()
        }
    }
}
