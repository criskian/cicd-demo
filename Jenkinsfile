pipeline {
    agent any

    environment {
        APP_IMAGE = 'mi-app:latest'
        APP_CONTAINER = 'mi-app'
        SONAR_PROJECT_KEY = 'mi-app'
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
                sh 'mvn -B sonar:sonar -Dsonar.projectKey=${SONAR_PROJECT_KEY} -Dsonar.host.url=${SONAR_HOST_URL} -Dsonar.login=${SONAR_TOKEN}'
            }
        }

        stage('Quality Gate (SonarQube)') {
            steps {
                sh '''
                    set -eu

                    TASK_ID=$(sed -n 's/^ceTaskId=//p' target/sonar/report-task.txt)
                    if [ -z "$TASK_ID" ]; then
                        echo "No se encontro ceTaskId en target/sonar/report-task.txt"
                        exit 1
                    fi

                    STATUS=""
                    ANALYSIS_ID=""
                    ATTEMPT=1
                    while [ "$ATTEMPT" -le 30 ]; do
                        RESPONSE=$(curl -s -u "${SONAR_TOKEN}:" "${SONAR_HOST_URL}/api/ce/task?id=${TASK_ID}")
                        STATUS=$(printf '%s' "$RESPONSE" | sed -n 's/.*"status":"\\([^"]*\\)".*/\\1/p')
                        ANALYSIS_ID=$(printf '%s' "$RESPONSE" | sed -n 's/.*"analysisId":"\\([^"]*\\)".*/\\1/p')

                        echo "SonarQube task status: ${STATUS}"
                        if [ "$STATUS" = "SUCCESS" ]; then
                            break
                        fi
                        if [ "$STATUS" = "FAILED" ] || [ "$STATUS" = "CANCELED" ]; then
                            echo "La tarea de SonarQube termino en estado ${STATUS}"
                            exit 1
                        fi

                        ATTEMPT=$((ATTEMPT + 1))
                        sleep 5
                    done

                    if [ "$STATUS" != "SUCCESS" ] || [ -z "$ANALYSIS_ID" ]; then
                        echo "SonarQube no termino el analisis a tiempo"
                        exit 1
                    fi

                    QUALITY_RESPONSE=$(curl -s -u "${SONAR_TOKEN}:" "${SONAR_HOST_URL}/api/qualitygates/project_status?analysisId=${ANALYSIS_ID}")
                    QUALITY_STATUS=$(printf '%s' "$QUALITY_RESPONSE" | sed -n 's/.*"projectStatus":{"status":"\\([^"]*\\)".*/\\1/p')
                    echo "SonarQube quality gate: ${QUALITY_STATUS}"

                    if [ "$QUALITY_STATUS" != "OK" ]; then
                        echo "El Quality Gate de SonarQube fallo"
                        exit 1
                    fi

                    HOTSPOT_RESPONSE=$(curl -s -u "${SONAR_TOKEN}:" "${SONAR_HOST_URL}/api/hotspots/search?projectKey=${SONAR_PROJECT_KEY}&status=TO_REVIEW")
                    HOTSPOTS=$(printf '%s' "$HOTSPOT_RESPONSE" | sed -n 's/.*"total":\\([0-9][0-9]*\\).*/\\1/p')
                    HOTSPOTS=${HOTSPOTS:-0}
                    echo "Security Hotspots pendientes: ${HOTSPOTS}"

                    if [ "$HOTSPOTS" -gt 0 ]; then
                        echo "SonarQube detecto Security Hotspots pendientes de revision"
                        exit 1
                    fi
                '''
            }
        }

        stage('Container Security Scan (Trivy)') {
            steps {
                sh 'docker build -t ${APP_IMAGE} .'
                sh 'trivy image --scanners vuln --pkg-types os --severity CRITICAL --exit-code 1 --ignore-unfixed ${APP_IMAGE}'
            }
        }

        stage('Deploy') {
            when {
                expression {
                    return !env.BRANCH_NAME || env.BRANCH_NAME == 'main' || env.BRANCH_NAME == 'master'
                }
            }
            steps {
                sh '''
                    docker rm -f ${APP_CONTAINER} || true
                    docker run -d --name ${APP_CONTAINER} -p 80:80 ${APP_IMAGE}
                '''
            }
        }

        stage('Validate') {
            steps {
                sh '''
                    sleep 15
                    docker logs ${APP_CONTAINER} | grep "Started CicdDemoApplication"
                    APP_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ${APP_CONTAINER})
                    curl -fsS http://${APP_IP}/config | grep "CI/CD Workshop Final Deployment"
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
        failure {
            echo 'Pipeline fallido: revisar logs de Jenkins, SonarQube o Trivy antes de desplegar.'
            sh 'docker rm -f ${APP_CONTAINER} || true'
        }
    }
}
