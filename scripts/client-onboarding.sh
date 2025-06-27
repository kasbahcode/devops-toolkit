#!/bin/bash

# 🎯 DevOps Toolkit Client Onboarding Script
# Guides new users through initial setup and customization

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

echo -e "${PURPLE}"
cat << 'EOF'
╔══════════════════════════════════════════════════════════════════╗
║              Welcome to DevOps Toolkit By Kasbah Code!           ║
║                                                                  ║
║     This script will guide you through the initial setup         ║
║     and help customize the toolkit for your needs.               ║
╚══════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Helper functions
log() {
    echo -e "${GREEN}[✅] $1${NC}"
}

info() {
    echo -e "${BLUE}[ℹ️] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[⚠️] $1${NC}"
}

error() {
    echo -e "${RED}[❌] $1${NC}"
    exit 1
}

prompt() {
    echo -e "${BLUE}$1${NC}"
}

# Step 1: Welcome and Prerequisites
welcome_user() {
    echo ""
    info "Step 1: Welcome and Prerequisites Check"
    echo ""
    
    prompt "This toolkit provides:"
    echo "  🚀 Complete DevOps automation"
    echo "  📊 Professional monitoring with Prometheus/Grafana"
    echo "  🔒 Security scanning and vulnerability management"
    echo "  ☁️ AWS infrastructure deployment"
    echo "  🔄 CI/CD pipelines with GitHub Actions"
    echo ""
    
    prompt "Prerequisites needed:"
    echo "  • Docker Desktop installed and running"
    echo "  • Git configured with your account"
    echo "  • At least 8GB RAM and 20GB disk space"
    echo "  • Internet connection for downloading dependencies"
    echo ""
    
    read -p "Do you have all prerequisites installed? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Please install prerequisites first:"
        echo "  • Docker: https://docs.docker.com/get-docker/"
        echo "  • Git: https://git-scm.com/downloads"
        echo ""
        info "Then run this script again!"
        exit 0
    fi
    
    log "Prerequisites check completed"
}

# Step 2: Environment Configuration
configure_environment() {
    echo ""
    info "Step 2: Environment Configuration"
    echo ""
    
    if [[ ! -f ".env" ]]; then
        prompt "Creating your environment configuration..."
        cp config.env.example .env
        log "Created .env file from template"
    else
        warn ".env file already exists"
        read -p "Do you want to overwrite it? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            cp config.env.example .env
            log "Overwritten .env file with template"
        fi
    fi
    
    echo ""
    prompt "Let's customize your configuration..."
    
    # Get user's email
    read -p "Enter your email address: " user_email
    if [[ -n "$user_email" ]]; then
        sed -i.bak "s/your-email@yourdomain.com/$user_email/g" .env && rm .env.bak
        log "Updated email configuration"
    fi
    
    # Get domain name
    read -p "Enter your domain name (optional, press Enter to skip): " domain_name
    if [[ -n "$domain_name" ]]; then
        sed -i.bak "s/yourdomain.com/$domain_name/g" .env && rm .env.bak
        log "Updated domain configuration"
    fi
    
    # Generate secure passwords
    prompt "Generating secure passwords..."
    
    postgres_pass=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    grafana_pass=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    smtp_pass=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    
    sed -i.bak "s/SecurePass123!ChangeMe/${postgres_pass}/g" .env && rm .env.bak
    sed -i.bak "s/GrafanaSecure456!ChangeMe/${grafana_pass}/g" .env && rm .env.bak
    sed -i.bak "s/SMTPSecure789!ChangeMe/${smtp_pass}/g" .env && rm .env.bak
    
    log "Generated and configured secure passwords"
    
    echo ""
    warn "IMPORTANT: Save these credentials securely!"
    echo "  Postgres Password: $postgres_pass"
    echo "  Grafana Password: $grafana_pass"
    echo ""
}

# Step 3: Choose Installation Type
choose_installation_type() {
    echo ""
    info "Step 3: Choose Installation Type"
    echo ""
    
    prompt "What type of installation do you want?"
    echo "  1) Development Setup (local development only)"
    echo "  2) Complete Setup (development + production ready)"
    echo "  3) Production Setup (full infrastructure deployment)"
    echo ""
    
    while true; do
        read -p "Choose option (1-3): " choice
        case $choice in
            1)
                INSTALL_TYPE="development"
                info "Selected: Development Setup"
                break
                ;;
            2)
                INSTALL_TYPE="complete"
                info "Selected: Complete Setup"
                break
                ;;
            3)
                INSTALL_TYPE="production"
                info "Selected: Production Setup"
                break
                ;;
            *)
                error "Invalid choice. Please enter 1, 2, or 3."
                ;;
        esac
    done
}

# Step 4: Run Setup
run_setup() {
    echo ""
    info "Step 4: Running Setup"
    echo ""
    
    log "Making all scripts executable..."
    chmod +x scripts/*.sh ssl/*.sh database/*.sh security/*.sh
    
    log "Running main setup script..."
    ./scripts/setup.sh
    
    if [[ "$INSTALL_TYPE" == "development" ]]; then
        log "Starting development environment..."
        docker compose up -d 2>/dev/null || docker-compose up -d
    elif [[ "$INSTALL_TYPE" == "complete" ]]; then
        log "Starting complete monitoring stack..."
        docker compose -f docker-compose.yml -f docker-compose.monitoring.yml up -d 2>/dev/null || docker-compose -f docker-compose.yml -f docker-compose.monitoring.yml up -d
    else
        info "Production setup requires additional AWS configuration"
        info "Please refer to docs/INSTALLATION.md for AWS setup instructions"
    fi
}

# Step 5: Validation and Next Steps
validate_and_next_steps() {
    echo ""
    info "Step 5: Validation and Next Steps"
    echo ""
    
    log "Running setup validation..."
    if ./scripts/validate-setup.sh; then
        log "Setup validation passed!"
    else
        warn "Setup validation found issues. Please review and fix them."
    fi
    
    echo ""
    prompt "🎉 Congratulations! Your DevOps Toolkit is ready!"
    echo ""
    
    echo "📋 What you can do now:"
    echo ""
    
    if [[ "$INSTALL_TYPE" == "development" || "$INSTALL_TYPE" == "complete" ]]; then
        echo "🌐 Access your applications:"
        echo "  • Main app: http://localhost:3000"
        echo "  • Grafana: http://localhost:3001 (admin/${grafana_pass})"
        echo "  • Prometheus: http://localhost:9090"
        echo ""
    fi
    
    echo "🚀 Create your first project:"
    echo "  ./scripts/init-project.sh my-awesome-app"
    echo ""
    
    echo "📊 Monitor your system:"
    echo "  ./scripts/monitor.sh health"
    echo ""
    
    echo "🔒 Run security scan:"
    echo "  ./scripts/security-scan.sh --all"
    echo ""
    
    echo "📚 Read the documentation:"
    echo "  • FAQ: docs/FAQ.md"
    echo "  • Use Cases: docs/USE-CASES.md"
    echo "  • Installation Guide: docs/INSTALLATION.md"
    echo ""
    
    echo "🆘 Need help?"
    echo "  • GitHub Issues: https://github.com/kasbahcode/devops-toolkit/issues"
    echo "  • Email: devops@kasbahcode.com"
    echo ""
    
    prompt "Save this information and start building amazing things! 🚀"
}

# Main execution
main() {
    welcome_user
    configure_environment
    choose_installation_type
    run_setup
    validate_and_next_steps
}

# Check if running as source or script
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 