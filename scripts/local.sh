#!/bin/bash

# Service Registry Local Development Script
# This script provides commands to build, run, and test the Spring Boot service registry

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="service_registry"
JAR_NAME="service_registry-0.0.1-SNAPSHOT.jar"
DEFAULT_PORT=8761
PID_FILE="service_registry.pid"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if Java is installed
check_java() {
    if ! command -v java &> /dev/null; then
        print_error "Java is not installed or not in PATH"
        exit 1
    fi
    
    JAVA_VERSION=$(java -version 2>&1 | head -n 1 | cut -d'"' -f2 | cut -d'.' -f1)
    if [ "$JAVA_VERSION" -lt "21" ]; then
        print_error "Java 21 or higher is required. Current version: $JAVA_VERSION"
        exit 1
    fi
    
    print_success "Java version: $(java -version 2>&1 | head -n 1)"
}

# Function to check if Maven is installed
check_maven() {
    if ! command -v mvn &> /dev/null; then
        print_error "Maven is not installed or not in PATH"
        exit 1
    fi
    
    print_success "Maven version: $(mvn -version | head -n 1)"
}

# Function to build the application
build() {
    print_status "Building $APP_NAME..."
    
    # Clean and compile
    mvn clean compile
    
    # Run tests
    mvn test
    
    # Package the application
    mvn package -DskipTests
    
    print_success "Build completed successfully!"
}

# Function to run the application
run() {
    local port=${1:-$DEFAULT_PORT}
    
    print_status "Starting $APP_NAME on port $port..."
    
    # Check if application is already running
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            print_warning "Application is already running with PID $pid"
            print_status "Use './scripts/local.sh stop' to stop it first"
            return 1
        else
            rm -f "$PID_FILE"
        fi
    fi
    
    # Start the application
    nohup java -jar target/$JAR_NAME --server.port=$port > service_registry.log 2>&1 &
    local pid=$!
    echo $pid > "$PID_FILE"
    
    print_success "Application started with PID $pid"
    print_status "Logs are being written to service_registry.log"
    print_status "Eureka dashboard will be available at http://localhost:$port"
    
    # Wait a moment and check if it started successfully
    sleep 3
    if ! ps -p "$pid" > /dev/null 2>&1; then
        print_error "Application failed to start. Check logs:"
        tail -n 20 service_registry.log
        rm -f "$PID_FILE"
        exit 1
    fi
    
    print_success "Application is running successfully!"
}

# Function to stop the application
stop() {
    print_status "Stopping $APP_NAME..."
    
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            kill "$pid"
            print_success "Application stopped (PID: $pid)"
        else
            print_warning "Application was not running"
        fi
        rm -f "$PID_FILE"
    else
        print_warning "No PID file found. Application may not be running."
    fi
}

# Function to restart the application
restart() {
    local port=${1:-$DEFAULT_PORT}
    print_status "Restarting $APP_NAME..."
    stop
    sleep 2
    run "$port"
}

# Function to check application status
status() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            print_success "Application is running (PID: $pid)"
            print_status "Eureka dashboard: http://localhost:$DEFAULT_PORT"
        else
            print_warning "PID file exists but application is not running"
            rm -f "$PID_FILE"
        fi
    else
        print_warning "Application is not running"
    fi
}

# Function to show logs
logs() {
    if [ -f "service_registry.log" ]; then
        tail -f service_registry.log
    else
        print_warning "No log file found. Application may not have been started."
    fi
}

# Function to run tests
test() {
    print_status "Running tests..."
    mvn test
    print_success "Tests completed!"
}

# Function to clean up
clean() {
    print_status "Cleaning up..."
    stop
    mvn clean
    rm -f service_registry.log
    print_success "Cleanup completed!"
}

# Function to show help
show_help() {
    echo "Service Registry Local Development Script"
    echo ""
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  build                    Build the application (clean, compile, test, package)"
    echo "  run [PORT]              Start the application (default port: $DEFAULT_PORT)"
    echo "  stop                    Stop the application"
    echo "  restart [PORT]          Restart the application"
    echo "  status                  Show application status"
    echo "  logs                    Show application logs (follow mode)"
    echo "  test                    Run tests only"
    echo "  clean                   Stop app, clean build artifacts and logs"
    echo "  help                    Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 build"
    echo "  $0 run"
    echo "  $0 run 8762"
    echo "  $0 restart"
    echo "  $0 logs"
}

# Main script logic
main() {
    # Change to project root directory
    cd "$(dirname "$0")/.."
    
    # Check prerequisites
    check_java
    check_maven
    
    case "${1:-help}" in
        "build")
            build
            ;;
        "run")
            run "$2"
            ;;
        "stop")
            stop
            ;;
        "restart")
            restart "$2"
            ;;
        "status")
            status
            ;;
        "logs")
            logs
            ;;
        "test")
            test
            ;;
        "clean")
            clean
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            print_error "Unknown command: $1"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
