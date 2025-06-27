#!/bin/bash

# 🚀 DevOps Toolkit Setup Script
# This script will either make your life easier or break your computer
# (Just kidding! It's tested on my machine and 3 others)

set -e

# Colors for output (because plain text is boring)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Global variables
OS=""
DISTRO=""
HOMEBREW_INSTALLED=""

# Logging functions (with timestamps because debugging is pain)
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    echo -e "${RED}If you're stuck, check the logs above or create a GitHub issue${NC}"
    exit 1
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

debug() {
    if [[ "${DEBUG:-false}" == "true" ]]; then
        echo -e "${PURPLE}[DEBUG] $1${NC}"
    fi
}

# Show usage
show_usage() {
    cat << EOF
🚀 DevOps Toolkit Setup Script

Usage: $0 [OPTIONS]

Options:
    --debug         Enable debug output (useful when things go wrong)
    --skip-docker   Skip Docker installation (if you already have it)
    --clean         Clean previous installations and start fresh
    -h, --help      Show this help message

Examples:
    $0                  # Standard installation
    $0 --debug          # Installation with debug output
    $0 --skip-docker    # Skip Docker (if you have Docker Desktop)

What this script does:
1. Detects your operating system (macOS, Linux, Windows)
2. Installs package managers (Homebrew on macOS)
3. Installs Docker, Node.js, kubectl, Terraform, Ansible
4. Sets up project structure and templates
5. Makes all scripts executable
6. Creates a .env template with secure defaults

Estimated time: 5-10 minutes (depends on your internet speed)
EOF
}

# Parse command line arguments
SKIP_DOCKER=false
CLEAN_INSTALL=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --debug)
            DEBUG=true
            shift
            ;;
        --skip-docker)
            SKIP_DOCKER=true
            shift
            ;;
        --clean)
            CLEAN_INSTALL=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Welcome message
echo -e "${GREEN}"
cat << 'EOF'
╔══════════════════════════════════════════════════════════════════╗
║                     DevOps Toolkit Setup                        ║
║                                                                  ║
║   This will install everything you need to get started with     ║
║   professional DevOps. Grab a coffee, this might take a bit.    ║
╚══════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Detect operating system
detect_os() {
    log "🔍 Detecting your operating system..."
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="linux"
        if [[ -f /etc/os-release ]]; then
            # Source the os-release file to get distribution info
            . /etc/os-release
            case "$ID" in
                ubuntu|debian)
                    DISTRO="debian"
                    ;;
                centos|rhel|fedora)
                    DISTRO="redhat"
                    ;;
                arch)
                    DISTRO="arch"
                    warn "Arch Linux detected. You probably know what you're doing anyway!"
                    ;;
                *)
                    DISTRO="unknown"
                    warn "Unknown Linux distribution. We'll try our best!"
                    ;;
            esac
        else
            DISTRO="unknown"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
        DISTRO="macos"
        # Check if we're on Apple Silicon or Intel
        if [[ $(uname -m) == "arm64" ]]; then
            info "Apple Silicon Mac detected (M1/M2)"
        else
            info "Intel Mac detected"
        fi
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "win32" ]]; then
        OS="windows"
        DISTRO="windows"
        warn "Windows detected. We strongly recommend using WSL2 for the best experience."
    else
        error "Unsupported operating system: $OSTYPE. Please check our documentation for manual installation steps."
    fi
    
    log "✅ Detected: $OS ($DISTRO)"
    debug "Full OS type: $OSTYPE"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if we have internet connectivity
check_internet() {
    log "🌐 Checking internet connectivity..."
    
    if ! ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        if ! ping -c 1 google.com >/dev/null 2>&1; then
            error "No internet connection detected. Please check your network and try again."
        fi
    fi
    
    log "✅ Internet connection is working"
}

# Clean previous installations
clean_previous_install() {
    if [[ "$CLEAN_INSTALL" == "true" ]]; then
        log "🧹 Cleaning previous installations..."
        
        # Remove any existing .env files
        rm -f .env .env.local .env.example
        
        # Clean up any temp files
        rm -rf tmp/ temp/ logs/
        
        log "✅ Cleanup completed"
    fi
}

# Install package manager on macOS
install_homebrew() {
    if [[ "$OS" != "macos" ]]; then
        return
    fi
    
    log "🍺 Installing/updating Homebrew..."
    
    if ! command_exists brew; then
        log "Installing Homebrew (this might ask for your password)..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        
        # Add Homebrew to PATH (different locations for Intel vs Apple Silicon)
        if [[ -f "/opt/homebrew/bin/brew" ]]; then
            # Apple Silicon
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zshrc
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [[ -f "/usr/local/bin/brew" ]]; then
            # Intel Mac
            echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.zshrc
            eval "$(/usr/local/bin/brew shellenv)"
        fi
        
        HOMEBREW_INSTALLED="true"
        log "✅ Homebrew installed successfully"
    else
        log "✅ Homebrew already installed, updating..."
        brew update || warn "Homebrew update failed, but we'll continue anyway"
    fi
}

# Update package managers
update_packages() {
    log "📦 Updating package managers..."
    
    case "$DISTRO" in
        debian)
            # Sometimes apt is locked by unattended upgrades, so we wait a bit
            sudo apt update && sudo apt upgrade -y || {
                warn "Package update failed. This sometimes happens on Ubuntu. Continuing anyway..."
            }
            ;;
        redhat)
            if command_exists dnf; then
                sudo dnf update -y
            else
                sudo yum update -y
            fi
            ;;
        arch)
            sudo pacman -Syu --noconfirm
            ;;
        macos)
            if [[ "$HOMEBREW_INSTALLED" == "true" ]]; then
                info "Homebrew was just installed, skipping update"
            else
                brew update
            fi
            ;;
        windows)
            warn "Please ensure you have the latest Windows updates installed"
            ;;
    esac
    
    log "✅ Package manager updates completed"
}

# Install Docker
install_docker() {
    if [[ "$SKIP_DOCKER" == "true" ]]; then
        log "⏭️ Skipping Docker installation as requested"
        return
    fi
    
    log "🐳 Installing Docker..."
    
    if command_exists docker; then
        log "✅ Docker already installed"
        # Quick sanity check because Docker can be installed but not running
        if ! docker info >/dev/null 2>&1; then
            warn "Docker is installed but not running."
            case "$OS" in
                macos)
                    warn "Starting Docker Desktop... (this might take 30 seconds)"
                    open -a Docker 2>/dev/null || warn "Couldn't start Docker Desktop automatically. Please start it manually."
                    ;;
                linux)
                    warn "Trying to start Docker service..."
                    sudo systemctl start docker || warn "Couldn't start Docker service. You might need to start it manually."
                    ;;
            esac
        fi
        return
    fi
    
    case "$DISTRO" in
        debian)
            log "Installing Docker on Debian/Ubuntu..."
            # Install prerequisites
            sudo apt install -y ca-certificates curl gnupg lsb-release
            
            # Add Docker's official GPG key
            sudo mkdir -p /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            
            # Add the repository
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
            
            # Install Docker
            sudo apt update
            sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            
            # Add user to docker group (so you don't need sudo for docker commands)
            sudo usermod -aG docker $USER
            
            warn "You'll need to log out and back in (or restart your terminal) for Docker permissions to take effect"
            ;;
        redhat)
            log "Installing Docker on CentOS/RHEL/Fedora..."
            if command_exists dnf; then
                # Fedora
                sudo dnf install -y dnf-plugins-core
                sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
                sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            else
                # CentOS/RHEL
                sudo yum install -y yum-utils
                sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
                sudo yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            fi
            
            sudo systemctl start docker
            sudo systemctl enable docker
            sudo usermod -aG docker $USER
            
            warn "You'll need to log out and back in for Docker permissions to take effect"
            ;;
        arch)
            sudo pacman -S docker docker-compose --noconfirm
            sudo systemctl start docker
            sudo systemctl enable docker
            sudo usermod -aG docker $USER
            ;;
        macos)
            log "Installing Docker Desktop on macOS..."
            if ! brew list --cask docker &>/dev/null; then
                brew install --cask docker
            fi
            warn "Please start Docker Desktop from Applications folder before continuing"
            warn "Docker Desktop might take a minute to start up the first time"
            ;;
        windows)
            error "Please install Docker Desktop from https://www.docker.com/products/docker-desktop and ensure WSL2 backend is enabled"
            ;;
    esac
    
    log "✅ Docker installation completed"
}

# Install Node.js
install_nodejs() {
    log "📦 Installing Node.js (we need this for basically everything)..."
    
    if command_exists node; then
        local version=$(node --version)
        local npm_version=$(npm --version 2>/dev/null || echo "unknown")
        log "✅ Node.js already installed: $version (npm: $npm_version)"
        
        # Check if it's a reasonable version
        local major_version=$(echo "$version" | sed 's/v//' | cut -d. -f1)
        if [[ $major_version -lt 16 ]]; then
            warn "You have Node.js $version, but we recommend v18+. Consider updating."
        fi
        return
    fi
    
    case "$DISTRO" in
        debian)
            log "Installing Node.js via NodeSource repository..."
            # Remove any existing nodejs packages to avoid conflicts
            sudo apt-get remove -y nodejs npm || true
            
            # Install NodeSource repository
            curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
            sudo apt-get install -y nodejs
            ;;
        redhat)
            log "Installing Node.js via NodeSource repository..."
            if command_exists dnf; then
                curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash -
                sudo dnf install -y nodejs npm
            else
                curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash -
                sudo yum install -y nodejs npm
            fi
            ;;
        arch)
            log "Installing Node.js via pacman..."
            sudo pacman -S nodejs npm --noconfirm
            ;;
        macos)
            log "Installing Node.js via Homebrew..."
            brew install node
            ;;
        windows)
            error "Please install Node.js LTS from https://nodejs.org/ and ensure it's in your PATH"
            ;;
    esac
    
    # Verify installation
    if command_exists node && command_exists npm; then
        local version=$(node --version)
        local npm_version=$(npm --version)
        log "✅ Node.js installation completed: $version (npm: $npm_version)"
        
        # Set npm to use a reasonable cache location
        npm config set cache ~/.npm-cache --global 2>/dev/null || true
    else
        error "Node.js installation failed. Please install manually and re-run this script."
    fi
}

# Install kubectl
install_kubectl() {
    log "Installing kubectl..."
    
    if command_exists kubectl; then
        log "✅ kubectl already installed"
        return
    fi
    
    case "$DISTRO" in
        debian)
            sudo apt-get update && sudo apt-get install -y apt-transport-https ca-certificates curl
            curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
            echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
            sudo apt-get update
            sudo apt-get install -y kubectl
            ;;
        redhat)
            curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
            sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
            rm kubectl
            ;;
        macos)
            brew install kubectl
            ;;
        windows)
            warn "Please install kubectl from https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/"
            ;;
    esac
    
    log "✅ kubectl installation completed"
}

# Install Terraform
install_terraform() {
    log "Installing Terraform..."
    
    if command_exists terraform; then
        log "✅ Terraform already installed"
        return
    fi
    
    case "$DISTRO" in
        debian)
            curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
            sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
            sudo apt-get update && sudo apt-get install terraform
            ;;
        redhat)
            sudo yum install -y yum-utils
            sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
            sudo yum -y install terraform
            ;;
        macos)
            brew install terraform
            ;;
        windows)
            warn "Please install Terraform from https://www.terraform.io/downloads"
            ;;
    esac
    
    log "✅ Terraform installation completed"
}

# Install Ansible
install_ansible() {
    log "Installing Ansible..."
    
    if command_exists ansible; then
        log "✅ Ansible already installed"
        return
    fi
    
    case "$DISTRO" in
        debian)
            sudo apt update
            sudo apt install -y ansible
            ;;
        redhat)
            sudo yum install -y epel-release
            sudo yum install -y ansible
            ;;
        macos)
            brew install ansible
            ;;
        windows)
            warn "Ansible is not natively supported on Windows. Use WSL2."
            ;;
    esac
    
    log "✅ Ansible installation completed"
}

# Install other tools
install_tools() {
    log "Installing additional tools..."
    
    case "$DISTRO" in
        debian)
            sudo apt install -y curl wget git jq unzip python3 python3-pip
            ;;
        redhat)
            sudo yum install -y curl wget git jq unzip python3 python3-pip
            ;;
        macos)
            brew install curl wget git jq unzip python3
            ;;
        windows)
            warn "Please ensure git, curl, and python3 are installed"
            ;;
    esac
    
    # Install Python packages (with fallbacks for common issues)
    if command_exists pip3; then
        log "Installing Python packages..."
        
        # Install AWS CLI v2 (preferred method)
        if ! command_exists aws; then
            if [[ "$OS" == "macos" ]]; then
                log "Installing AWS CLI v2 for macOS..."
                curl -s "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg" || true
                if [[ -f "AWSCLIV2.pkg" ]]; then
                    sudo installer -pkg AWSCLIV2.pkg -target / 2>/dev/null || warn "AWS CLI installation via pkg failed, trying pip"
                    rm -f AWSCLIV2.pkg
                fi
            fi
            
            # Fallback to pip if AWS CLI v2 installation failed
            if ! command_exists aws; then
                pip3 install --user --upgrade awscli 2>/dev/null || warn "Could not install AWS CLI"
            fi
        fi
        
        # Docker Compose v2 is built into Docker Desktop, but install standalone for Linux
        if [[ "$OS" == "linux" ]] && ! docker compose version >/dev/null 2>&1; then
            log "Installing Docker Compose v2..."
            mkdir -p ~/.docker/cli-plugins/
            curl -sL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64" -o ~/.docker/cli-plugins/docker-compose 2>/dev/null || warn "Could not install Docker Compose"
            chmod +x ~/.docker/cli-plugins/docker-compose 2>/dev/null || true
        fi
        
        # Install other useful Python packages (with error handling)
        pip3 install --user --upgrade pip setuptools wheel 2>/dev/null || warn "Could not upgrade pip"
        pip3 install --user pyyaml requests urllib3 2>/dev/null || warn "Some Python packages could not be installed"
    fi
    
    log "✅ Additional tools installation completed"
}

# Create .env template
create_env_template() {
    log "📄 Creating .env template..."
    
    # Generate secure random passwords
    local postgres_pass="$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25 || echo 'secure_postgres_pass')"
    local jwt_secret="$(openssl rand -base64 48 | tr -d "=+/" | cut -c1-40 || echo 'secure_jwt_secret')"
    local grafana_pass="$(openssl rand -base64 16 | tr -d "=+/" | cut -c1-12 || echo 'admin123')"
    
    cat > .env.template << EOF
# DevOps Toolkit Environment Configuration
# Copy this file to .env and customize for your needs

# Application Settings
NODE_ENV=development
PORT=3000
DEBUG=false

# Database Configuration
POSTGRES_DB=devops_toolkit
POSTGRES_USER=postgres
POSTGRES_PASSWORD=$postgres_pass
DATABASE_URL=postgresql://postgres:$postgres_pass@localhost:5432/devops_toolkit

# Redis Configuration
REDIS_URL=redis://localhost:6379

# JWT Secret (keep this secure!)
JWT_SECRET=$jwt_secret

# Kubernetes Configuration
NAMESPACE=default
KUBECONFIG=~/.kube/config

# AWS Configuration (optional)
AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...
AWS_DEFAULT_REGION=us-east-1

# Azure Configuration (optional)
AZURE_CLIENT_ID=...
AZURE_CLIENT_SECRET=...
AZURE_TENANT_ID=...

# Monitoring (secure defaults generated)
GRAFANA_ADMIN_PASSWORD=$grafana_pass
PROMETHEUS_RETENTION_DAYS=15

# Alerting
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/...
ALERT_EMAIL=alerts@yourcompany.com

# SSL Configuration
SSL_ENABLED=false
SSL_CERT_PATH=./ssl/cert.pem
SSL_KEY_PATH=./ssl/key.pem

# Backup Configuration
BACKUP_ENABLED=true
BACKUP_SCHEDULE="0 2 * * *"
BACKUP_RETENTION_DAYS=30
EOF
    
    log "✅ Created .env.template with secure defaults"
}

# Set up directories
create_directories() {
    log "📁 Creating directory structure..."
    
    mkdir -p {logs,ssl,backups,scripts}
    chmod 755 scripts
    
    log "✅ Directory structure created"
}

# Make scripts executable
make_scripts_executable() {
    log "🔧 Making scripts executable..."
    
    find scripts -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
    find ssl -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
    find database -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
    find security -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
    
    log "✅ Scripts are now executable"
}

# Main setup function
main() {
    log "🚀 Starting DevOps Toolkit setup..."
    
    detect_os
    
    case "$DISTRO" in
        macos)
            install_homebrew
            ;;
    esac
    
    update_packages
    install_docker
    install_nodejs
    install_kubectl
    install_terraform
    install_ansible
    install_tools
    create_env_template
    create_directories
    make_scripts_executable
    
    log "🎉 Setup complete! Time to build something awesome."
    log ""
    log "📋 What's next:"
    log "1. Copy .env.template to .env and fill in your details"
    log "2. Make sure Docker Desktop is running (if you're on macOS/Windows)"
    log "3. Create your first project: './scripts/init-project.sh my-first-project'"
    log "4. Verify everything works: './scripts/monitor.sh health'"
    log ""
    log "📖 Stuck? Check these out:"
    log "- Installation troubleshooting: docs/INSTALLATION.md"
    log "- Real-world examples: docs/USE-CASES.md"
    log "- Common issues: docs/FAQ.md"
    log ""
    log "🔧 Still having issues? Create a GitHub issue with your error logs!"
}

# Run main function
main "$@" 