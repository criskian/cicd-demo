
# CICD-DEMO

This project aims to be the basic skeleton to apply continuous integration and continuous delivery.

## Topology

CICD Demo uses some kubernetes primitives to deploy:

* Deployment
* Services
* Ingress ( with TLS )

```bash
     internet
        |
   [ Ingress ]
   --|-----|--
   [ Services ]
   --|-----|--
   [   Pods   ]

```

This project includes:

* Spring Boot java app
* Jenkinsfile integration to run pipelines
* Dockerfile containing the base image to run java apps
* Makefile and docker-compose to make the pipeline steps much simpler
* Kubernetes deployment file demonstrating how to deploy this app in a simple Kubernetes cluster

## Pipeline Setup

Pipelines exist at Travis.

Some pipelines are configured by **GitHub/Projects**. If you have created a repository in one of these, your project will be **automatically** built if it has a Jenkinsfile/Travis/Gitlab/CircleCI.

Other pipelines are configured manually under folders. You can create a project manually with the following steps:

How to run the app:

```make
make
```

## Testing

Unit tests and integrations tests are separated using [JUnit Categories][].

[JUnit Categories]: https://maven.apache.org/surefire/maven-surefire-plugin/examples/junit.html

### Unit Tests

```java
mvn test -Dgroups=UnitTest
```

Or using Docker:

```bash
make build
```

### Integration Tests

```java
mvn integration-test -Dgroups=IntegrationTests
```

Or using Docker:

```bash
make integrationTest
```

### System Tests

System tests run with Selenium using docker-compose to run a [Selenium standalone container][] with Chrome.

[Selenium standalone container]: https://github.com/SeleniumHQ/docker-selenium

Using Docker:

* If you are running locally, make sure the `$APP_URL` is populated and points to a valid instance of your application. This variable is populated automatically in Jenkins.

```bash
APP_URL=http://dev-cicd-demo-master.anzcd.internal/ make systemTest
```

## Jenkins workshop pipeline

This repository includes a Jenkins declarative pipeline for a local CI/CD workshop.
The pipeline reads the `Jenkinsfile` from SCM and validates the application before
deployment.

### Local infrastructure

Run Jenkins with access to the Docker daemon so the pipeline can build and run
containers:

```bash
docker run -d --name jenkins-cicd -u root \
  -p 8080:8080 -p 50000:50000 \
  -v jenkins_cicd_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  jenkins/jenkins:lts-jdk17
```

Create a shared Docker network and run SonarQube:

```bash
docker network create cicd-workshop
docker network connect cicd-workshop jenkins-cicd
docker run -d --name sonarqube --network cicd-workshop \
  -p 9000:9000 \
  -e SONAR_ES_BOOTSTRAP_CHECKS_DISABLE=true \
  sonarqube:lts-community
```

Install Maven, Docker CLI and Trivy in the Jenkins agent/container:

```bash
apt-get update
apt-get install -y maven docker.io wget gnupg
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key \
  | gpg --dearmor > /usr/share/keyrings/trivy.gpg
echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" \
  > /etc/apt/sources.list.d/trivy.list
apt-get update
apt-get install -y trivy
```

In Jenkins, create a `Secret text` credential with ID `sonar-token`. The secret
value must be a SonarQube user token created from `http://localhost:9000`.

### Jenkins job

Create a Jenkins Pipeline job using:

```text
Definition: Pipeline script from SCM
SCM: Git
Repository URL: https://github.com/criskian/cicd-demo.git
Branch Specifier: */master
Script Path: Jenkinsfile
```

### Pipeline stages

The pipeline executes:

* `Checkout`: obtains the source code from GitHub.
* `Build & Test`: runs Maven package with unit and integration tests.
* `Static Analysis (SonarQube)`: sends analysis to SonarQube.
* `Quality Gate (SonarQube)`: fails if the SonarQube Quality Gate fails or if
  pending Security Hotspots are detected.
* `Container Security Scan (Trivy)`: builds the Docker image and fails if Trivy
  finds `CRITICAL` operating-system vulnerabilities in the image.
* `Deploy`: deploys `mi-app:latest` with `docker run -d -p 80:80 mi-app:latest`
  for `master`/`main`.
* `Validate`: verifies that the deployed Spring Boot app started correctly.
* `post`: publishes test results and artifacts, cleans the workspace and removes
  partial deployments when the pipeline fails. The `failure` block prints a
  clear notification message in the Jenkins console.

### Expected evidence

Capture the following evidence for the workshop:

* Jenkins job configuration showing `Pipeline script from SCM`.
* Stage View showing the advanced stages.
* Console output showing `ANALYSIS SUCCESSFUL` from SonarQube.
* SonarQube dashboard for project `mi-app`.
* Console output from the SonarQube quality gate, including Security Hotspots.
* Console output from Trivy. If `CRITICAL` vulnerabilities are found, the
  pipeline must fail before `Deploy`.
* If all gates pass, browser validation at `http://localhost/config`.

### Final deployment test

The application exposes a visible deployment marker at `/config`:

```text
Current profile CI/CD Workshop Final Deployment
```

To demonstrate the final CI/CD flow, commit a small text change, push it to
GitHub and run the Jenkins job again. Jenkins should detect the SCM change,
build the JAR, analyze the code, scan the Docker image, deploy the container and
validate the final response when all gates pass.
