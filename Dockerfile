# Service Registry Dockerfile
FROM openjdk:21-jdk-slim

# Set working directory
WORKDIR /app

# Copy Maven files for dependency caching
COPY pom.xml .
COPY mvnw .
COPY .mvn .mvn

# Make mvnw executable
RUN chmod +x ./mvnw

# Download dependencies
RUN ./mvnw dependency:go-offline -B

# Copy source code
COPY src ./src

# Build the application
RUN ./mvnw clean package -DskipTests

# Install curl for health checks
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN addgroup --system spring && adduser --system spring --ingroup spring

# Environment variables
ENV SPRING_PROFILES_ACTIVE=docker

USER spring:spring

# Expose port
EXPOSE 8761

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
  CMD curl -f http://localhost:8761/actuator/health || exit 1

# Run the application
ENTRYPOINT ["java", "-jar", "target/service_registry-0.0.1-SNAPSHOT.jar"]
