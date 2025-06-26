#!/bin/bash

# 🚀 DevOps Toolkit Setup Script
# Automatically sets up the development environment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
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

# Check if running on macOS or Linux
OS="$(uname -s)"
case "${OS}" in
    Linux*)     MACHINE=Linux;;
    Darwin*)    MACHINE=Mac;;
    *)          MACHINE="UNKNOWN:${OS}"
esac

log "🔍 Detected OS: $MACHINE"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install Docker
install_docker() {
    log "🐳 Installing Docker..."
    
    if command_exists docker; then
        log "✅ Docker already installed"
        return
    fi
    
    if [[ "$MACHINE" == "Mac" ]]; then
        if command_exists brew; then
            brew install --cask docker
        else
            warn "Please install Docker Desktop manually from https://docker.com"
        fi
    elif [[ "$MACHINE" == "Linux" ]]; then
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh
        sudo usermod -aG docker $USER
        rm get-docker.sh
    fi
}

# Install Docker Compose
install_docker_compose() {
    log "🔧 Installing Docker Compose..."
    
    if command_exists docker-compose; then
        log "✅ Docker Compose already installed"
        return
    fi
    
    if [[ "$MACHINE" == "Mac" ]]; then
        # Usually comes with Docker Desktop
        log "✅ Docker Compose comes with Docker Desktop"
    elif [[ "$MACHINE" == "Linux" ]]; then
        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
    fi
}

# Install kubectl
install_kubectl() {
    log "☸️ Installing kubectl..."
    
    if command_exists kubectl; then
        log "✅ kubectl already installed"
        return
    fi
    
    if [[ "$MACHINE" == "Mac" ]]; then
        if command_exists brew; then
            brew install kubectl
        else
            curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/darwin/amd64/kubectl"
            chmod +x kubectl
            sudo mv kubectl /usr/local/bin/
        fi
    elif [[ "$MACHINE" == "Linux" ]]; then
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        chmod +x kubectl
        sudo mv kubectl /usr/local/bin/
    fi
}

# Install Terraform
install_terraform() {
    log "🏗️ Installing Terraform..."
    
    if command_exists terraform; then
        log "✅ Terraform already installed"
        return
    fi
    
    if [[ "$MACHINE" == "Mac" ]]; then
        if command_exists brew; then
            brew tap hashicorp/tap
            brew install hashicorp/tap/terraform
        fi
    elif [[ "$MACHINE" == "Linux" ]]; then
        wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
        echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
        sudo apt update && sudo apt install terraform
    fi
}

# Install Ansible
install_ansible() {
    log "📋 Installing Ansible..."
    
    if command_exists ansible; then
        log "✅ Ansible already installed"
        return
    fi
    
    if command_exists pip3; then
        pip3 install ansible
    elif command_exists pip; then
        pip install ansible
    else
        if [[ "$MACHINE" == "Mac" ]]; then
            if command_exists brew; then
                brew install ansible
            fi
        elif [[ "$MACHINE" == "Linux" ]]; then
            sudo apt update
            sudo apt install ansible -y
        fi
    fi
}

# Install Node.js
install_nodejs() {
    log "🟢 Installing Node.js..."
    
    if command_exists node; then
        log "✅ Node.js already installed"
        return
    fi
    
    if [[ "$MACHINE" == "Mac" ]]; then
        if command_exists brew; then
            brew install node
        fi
    elif [[ "$MACHINE" == "Linux" ]]; then
        curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
        sudo apt-get install -y nodejs
    fi
}

# Install Python3
install_python() {
    log "🐍 Installing Python3..."
    
    if command_exists python3; then
        log "✅ Python3 already installed"
        return
    fi
    
    if [[ "$MACHINE" == "Mac" ]]; then
        if command_exists brew; then
            brew install python
        fi
    elif [[ "$MACHINE" == "Linux" ]]; then
        sudo apt update
        sudo apt install python3 python3-pip -y
    fi
}

# Create .env template
create_env_template() {
    log "📄 Creating .env template..."
    
    cat > .env.template << 'EOF'
# DevOps Toolkit Environment Variables

# Docker Registry
DOCKER_REGISTRY=your-registry.com
DOCKER_USERNAME=your-username
DOCKER_PASSWORD=your-password

# Kubernetes
KUBECONFIG=~/.kube/config
NAMESPACE=default

# AWS (if using)
AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret-key
AWS_DEFAULT_REGION=us-east-1

# GCP (if using)
GOOGLE_APPLICATION_CREDENTIALS=path/to/service-account.json
GCP_PROJECT_ID=your-project-id

# Azure (if using)
AZURE_CLIENT_ID=your-client-id
AZURE_CLIENT_SECRET=your-client-secret
AZURE_TENANT_ID=your-tenant-id

# Monitoring
GRAFANA_ADMIN_PASSWORD=admin123
PROMETHEUS_RETENTION=15d

# Databases
POSTGRES_USER=postgres
POSTGRES_PASSWORD=password123
REDIS_PASSWORD=redis123

# SSL/TLS
ACME_EMAIL=your-email@domain.com
DOMAIN_NAME=your-domain.com

# CI/CD
GITHUB_TOKEN=your-github-token
GITLAB_TOKEN=your-gitlab-token
EOF

    log "✅ Created .env.template - Copy to .env and fill in your values"
}

# Make scripts executable
make_executable() {
    log "🔧 Making scripts executable..."
    chmod +x scripts/*.sh
    log "✅ Scripts are now executable"
}

# Main setup function
main() {
    log "🚀 Starting DevOps Toolkit Setup..."
    
    # Check for required tools
    log "📦 Installing required tools..."
    
    install_docker
    install_docker_compose
    install_kubectl
    install_terraform
    install_ansible
    install_nodejs
    install_python
    
    # Setup project
    create_env_template
    make_executable
    
    log "✅ Setup completed successfully!"
    log "🎉 DevOps Toolkit is ready to use!"
    log ""
    log "Next steps:"
    log "1. Copy .env.template to .env and fill in your values"
    log "2. Run './scripts/init-project.sh your-project-name' to start a new project"
    log "3. Check out the documentation in each directory"
}

# Run main function
main "$@" 