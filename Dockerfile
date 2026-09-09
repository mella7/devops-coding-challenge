# Build stage
FROM eclipse-temurin:17-jdk-jammy AS builder
WORKDIR /app

# pom.xml first, source later - keeps this layer cached between builds
COPY mvnw pom.xml ./
COPY .mvn .mvn

# grab deps now so they're cached too
RUN ./mvnw dependency:go-offline

COPY src ./src
RUN ./mvnw clean package -DskipTests

# Runtime stage - no JDK/Maven, just the jar
FROM eclipse-temurin:17-jre-jammy

# numeric UID/GID, not just a name - k8s runAsNonRoot checks this reliably
RUN groupadd -r -g 10001 appgroup && useradd -r -u 10001 -g appgroup appuser

WORKDIR /app

# --chown here avoids a separate RUN chown layer
COPY --from=builder --chown=appuser:appgroup /app/target/*.jar app.jar

USER 10001:10001

EXPOSE 8080

# checks the app is actually responding, not just that the process is alive
HEALTHCHECK --interval=15s --timeout=3s --start-period=30s \
  CMD wget -qO- http://localhost:8080/actuator/health || exit 1

ENTRYPOINT ["java", "-jar", "app.jar"]
