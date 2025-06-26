#!/bin/bash

# 🚀 Deployment Automation Script
# Handles deployment to different environments

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

# Default values
ENVIRONMENT="staging"
SERVICE_NAME=""
IMAGE_TAG="latest"
NAMESPACE="default"
REGISTRY="ghcr.io"
BUILD_ONLY="false"
SKIP_TESTS="false"

# Usage function
usage() {
    cat << EOF
🚀 Deployment Automation Script

Usage: $0 [OPTIONS]

Options:
    -e, --environment ENV    Target environment (staging, production) [default: staging]
    -s, --service NAME       Service name to deploy
    -t, --tag TAG           Image tag to deploy [default: latest]
    -n, --namespace NS      Kubernetes namespace [default: default]
    -r, --registry URL      Docker registry URL [default: ghcr.io]
    -b, --build-only        Only build, don't deploy
    --skip-tests           Skip running tests
    -h, --help             Show this help message

Examples:
    $0 -e staging -s my-api
    $0 -e production -s my-api -t v1.2.3
    $0 --build-only -s my-api
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -s|--service)
            SERVICE_NAME="$2"
            shift 2
            ;;
        -t|--tag)
            IMAGE_TAG="$2"
            shift 2
            ;;
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -r|--registry)
            REGISTRY="$2"
            shift 2
            ;;
        -b|--build-only)
            BUILD_ONLY="true"
            shift
            ;;
        --skip-tests)
            SKIP_TESTS="true"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            ;;
    esac
done

# Validate required parameters
if [[ -z "$SERVICE_NAME" ]]; then
    error "Service name is required. Use -s or --service option."
fi

# Validate environment
if [[ "$ENVIRONMENT" != "staging" && "$ENVIRONMENT" != "production" ]]; then
    error "Environment must be 'staging' or 'production'"
fi

# Check required tools
check_dependencies() {
    log "🔍 Checking dependencies..."
    
    local deps=("docker" "kubectl")
    if [[ "$SKIP_TESTS" != "true" ]]; then
        deps+=("npm")
    fi
    
    for cmd in "${deps[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            error "$cmd is required but not installed"
        fi
    done
    
    log "✅ All dependencies are available"
}

# Load environment configuration
load_config() {
    log "📋 Loading configuration for $ENVIRONMENT environment..."
    
    local config_file="config/$ENVIRONMENT.env"
    if [[ -f "$config_file" ]]; then
        source "$config_file"
        log "✅ Loaded configuration from $config_file"
    else
        warn "Configuration file $config_file not found, using defaults"
    fi
    
    # Set full image name
    FULL_IMAGE_NAME="$REGISTRY/$SERVICE_NAME:$IMAGE_TAG"
    
    log "Configuration:"
    log "  Environment: $ENVIRONMENT"
    log "  Service: $SERVICE_NAME"
    log "  Image: $FULL_IMAGE_NAME"
    log "  Namespace: $NAMESPACE"
}

# Run tests
run_tests() {
    if [[ "$SKIP_TESTS" == "true" ]]; then
        warn "Skipping tests as requested"
        return
    fi
    
    log "🧪 Running tests..."
    
    if [[ -f "package.json" ]]; then
        npm test
    elif [[ -f "requirements.txt" ]]; then
        python -m pytest
    elif [[ -f "go.mod" ]]; then
        go test ./...
    else
        warn "No test configuration found, skipping tests"
    fi
    
    log "✅ Tests passed"
}

# Build Docker image
build_image() {
    log "🐳 Building Docker image: $FULL_IMAGE_NAME"
    
    # Check if Dockerfile exists
    if [[ ! -f "Dockerfile" ]]; then
        error "Dockerfile not found in current directory"
    fi
    
    # Build image with buildkit for better performance
    DOCKER_BUILDKIT=1 docker build \
        --tag "$FULL_IMAGE_NAME" \
        --build-arg ENVIRONMENT="$ENVIRONMENT" \
        --build-arg BUILD_DATE="$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
        --build-arg VCS_REF="$(git rev-parse HEAD 2>/dev/null || echo 'unknown')" \
        .
    
    log "✅ Docker image built successfully"
}

# Push image to registry
push_image() {
    log "📤 Pushing image to registry..."
    
    # Login to registry if credentials are available
    if [[ -n "$REGISTRY_USERNAME" && -n "$REGISTRY_PASSWORD" ]]; then
        echo "$REGISTRY_PASSWORD" | docker login "$REGISTRY" -u "$REGISTRY_USERNAME" --password-stdin
    fi
    
    docker push "$FULL_IMAGE_NAME"
    
    log "✅ Image pushed to registry"
}

# Deploy to Kubernetes
deploy_to_k8s() {
    log "☸️ Deploying to Kubernetes..."
    
    # Check if kubectl is configured
    if ! kubectl cluster-info >/dev/null 2>&1; then
        error "kubectl is not configured or cluster is not accessible"
    fi
    
    # Create namespace if it doesn't exist
    kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    
    # Check if deployment manifest exists
    local manifest_file="k8s/$ENVIRONMENT"
    if [[ ! -d "$manifest_file" ]]; then
        manifest_file="k8s"
    fi
    
    if [[ ! -d "$manifest_file" ]]; then
        error "Kubernetes manifests not found. Expected: k8s/$ENVIRONMENT or k8s/"
    fi
    
    # Update image in deployment
    if [[ -f "$manifest_file/deployment.yaml" ]]; then
        # Use envsubst to replace environment variables in manifests
        export SERVICE_NAME FULL_IMAGE_NAME NAMESPACE ENVIRONMENT
        
        envsubst < "$manifest_file/deployment.yaml" | kubectl apply -f -
        
        # Apply other manifests
        for file in "$manifest_file"/*.yaml; do
            if [[ "$file" != "$manifest_file/deployment.yaml" ]]; then
                envsubst < "$file" | kubectl apply -f -
            fi
        done
    else
        # Apply all manifests in directory
        kubectl apply -f "$manifest_file/" -n "$NAMESPACE"
    fi
    
    # Wait for deployment to be ready
    log "⏳ Waiting for deployment to be ready..."
    kubectl rollout status deployment/"$SERVICE_NAME" -n "$NAMESPACE" --timeout=300s
    
    log "✅ Deployment completed successfully"
}

# Verify deployment
verify_deployment() {
    log "🔍 Verifying deployment..."
    
    # Check pod status
    kubectl get pods -n "$NAMESPACE" -l app="$SERVICE_NAME"
    
    # Check service endpoints
    if kubectl get service "$SERVICE_NAME" -n "$NAMESPACE" >/dev/null 2>&1; then
        kubectl get endpoints "$SERVICE_NAME" -n "$NAMESPACE"
    fi
    
    # Try to get service URL
    local service_url
    if command -v minikube >/dev/null 2>&1 && minikube status >/dev/null 2>&1; then
        service_url=$(minikube service "$SERVICE_NAME" -n "$NAMESPACE" --url 2>/dev/null || echo "")
    fi
    
    if [[ -n "$service_url" ]]; then
        log "🌐 Service URL: $service_url"
        
        # Test health endpoint if available
        if curl -sf "$service_url/health" >/dev/null 2>&1; then
            log "✅ Health check passed"
        else
            warn "Health check endpoint not accessible"
        fi
    fi
    
    log "✅ Deployment verification completed"
}

# Rollback deployment
rollback_deployment() {
    log "🔄 Rolling back deployment..."
    
    kubectl rollout undo deployment/"$SERVICE_NAME" -n "$NAMESPACE"
    kubectl rollout status deployment/"$SERVICE_NAME" -n "$NAMESPACE" --timeout=300s
    
    log "✅ Rollback completed"
}

# Main deployment function
main() {
    log "🚀 Starting deployment process..."
    log "Target: $ENVIRONMENT environment"
    
    # Trap to handle failures
    trap 'error "Deployment failed! Use --rollback to revert changes"' ERR
    
    check_dependencies
    load_config
    run_tests
    build_image
    
    if [[ "$BUILD_ONLY" == "true" ]]; then
        log "🎉 Build completed successfully (build-only mode)"
        return
    fi
    
    push_image
    deploy_to_k8s
    verify_deployment
    
    log "🎉 Deployment completed successfully!"
    log ""
    log "📊 Deployment Summary:"
    log "  Environment: $ENVIRONMENT"
    log "  Service: $SERVICE_NAME"
    log "  Image: $FULL_IMAGE_NAME"
    log "  Namespace: $NAMESPACE"
    log ""
    log "🔧 Useful commands:"
    log "  kubectl get pods -n $NAMESPACE"
    log "  kubectl logs -f deployment/$SERVICE_NAME -n $NAMESPACE"
    log "  kubectl describe deployment $SERVICE_NAME -n $NAMESPACE"
}

# Handle rollback if requested
if [[ "$1" == "--rollback" ]]; then
    rollback_deployment
    exit 0
fi

# Run main deployment
main "$@" 