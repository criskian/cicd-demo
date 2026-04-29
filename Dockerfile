FROM eclipse-temurin:11-jre
VOLUME /tmp
COPY target/cicd-demo-*.jar app.jar
EXPOSE 80
ENTRYPOINT [ "java","-Djava.security.egd=file:/dev/./unrandom","-jar","/app.jar" ]
