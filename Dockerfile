FROM eclipse-temurin:17-jdk-jammy
WORKDIR /app
COPY target/spring-boot-demo-api-1.0-SNAPSHOT.jar app.jar
ENTRYPOINT ["java", "-jar", "app.jar"]