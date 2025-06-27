#!/bin/bash

# 🔍 DevOps Toolkit Setup Validation Script
# Ensures the toolkit is properly configured for production use

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Validation results
ISSUES=0
WARNINGS=0

log() {
    echo -e "${GREEN}[✅] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[⚠️] $1${NC}"
    ((WARNINGS++))
}

error() {
    echo -e "${RED}[❌] $1${NC}"
    ((ISSUES++))
}

info() {
    echo -e "${BLUE}[ℹ️] $1${NC}"
}

echo -e "${BLUE}"
cat << 'EOF'
╔══════════════════════════════════════════════════════════════════╗
║                DevOps Toolkit Setup Validation                  ║
║             Checking Production Readiness                       ║
╚══════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Check 1: Environment Configuration
check_environment_config() {
    info "Checking environment configuration..."
    
    if [[ -f ".env" ]]; then
        log "Environment file (.env) exists"
        
        # Check for default passwords
        if grep -q "CHANGEME\|ChangeMe\|admin123\|password123" .env 2>/dev/null; then
            error "Default passwords found in .env file - SECURITY RISK!"
            error "Update all passwords before production deployment"
        else
            log "No default passwords found in .env"
        fi
        
        # Check required variables
        local required_vars=("POSTGRES_PASSWORD" "GRAFANA_ADMIN_PASSWORD" "SSL_EMAIL")
        for var in "${required_vars[@]}"; do
            if grep -q "^${var}=" .env 2>/dev/null; then
                log "Required variable $var is configured"
            else
                warn "Required variable $var is missing from .env"
            fi
        done
    else
        warn ".env file not found - copy from config.env.example"
    fi
}

# Check 2: Docker Setup
check_docker_setup() {
    info "Checking Docker configuration..."
    
    if command -v docker >/dev/null 2>&1; then
        log "Docker is installed"
        
        if docker info >/dev/null 2>&1; then
            log "Docker daemon is running"
        else
            error "Docker daemon is not running"
        fi
    else
        error "Docker is not installed"
    fi
    
    if [[ -f "docker-compose.yml" ]]; then
        log "Main docker-compose.yml exists"
    else
        error "Main docker-compose.yml is missing"
    fi
    
    if [[ -f "docker-compose.monitoring.yml" ]]; then
        log "Monitoring docker-compose.yml exists"
    else
        error "Monitoring docker-compose configuration is missing"
    fi
}

# Check 3: Security Configuration
check_security_config() {
    info "Checking security configuration..."
    
    # Check SSL configuration
    if [[ -f "ssl/generate-certs.sh" ]]; then
        log "SSL certificate generation script exists"
        if [[ -x "ssl/generate-certs.sh" ]]; then
            log "SSL script is executable"
        else
            warn "SSL script is not executable - run: chmod +x ssl/generate-certs.sh"
        fi
    else
        error "SSL certificate script is missing"
    fi
    
    # Check security scanning
    if [[ -f "scripts/security-scan.sh" ]]; then
        log "Security scanning script exists"
    else
        error "Security scanning script is missing"
    fi
}

# Check 4: Monitoring Setup
check_monitoring_setup() {
    info "Checking monitoring configuration..."
    
    local monitoring_files=(
        "monitoring/prometheus/prometheus.yml"
        "monitoring/alertmanager/alertmanager.yml"
        "monitoring/prometheus/rules/alerts.yml"
    )
    
    for file in "${monitoring_files[@]}"; do
        if [[ -f "$file" ]]; then
            log "Monitoring file exists: $file"
        else
            error "Missing monitoring file: $file"
        fi
    done
    
    # Check for Grafana dashboards
    if [[ -f "monitoring/grafana/provisioning/dashboards/main-dashboard.json" ]]; then
        log "Grafana dashboard template exists"
    else
        warn "Grafana dashboard template is missing"
    fi
}

# Check 5: Infrastructure as Code
check_infrastructure() {
    info "Checking infrastructure configuration..."
    
    if [[ -f "terraform/main.tf" ]]; then
        log "Terraform main configuration exists"
    else
        error "Terraform configuration is missing"
    fi
    
    if [[ -f "terraform/variables.tf" ]]; then
        log "Terraform variables configuration exists"
    else
        error "Terraform variables configuration is missing"
    fi
    
    if [[ -f "kubernetes/namespace.yaml" ]]; then
        log "Kubernetes namespace configuration exists"
    else
        error "Kubernetes configuration is missing"
    fi
}

# Check 6: CI/CD Pipeline
check_cicd() {
    info "Checking CI/CD configuration..."
    
    if [[ -f ".github/workflows/github-actions.yml" ]] || [[ -f "ci-cd/github-actions.yml" ]]; then
        log "GitHub Actions workflow exists"
    else
        error "CI/CD pipeline configuration is missing"
    fi
}

# Check 7: Scripts Permissions
check_script_permissions() {
    info "Checking script permissions..."
    
    local scripts=(
        "scripts/setup.sh"
        "scripts/deploy.sh"
        "scripts/monitor.sh"
        "scripts/backup.sh"
        "scripts/init-project.sh"
        "scripts/security-scan.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [[ -f "$script" ]]; then
            if [[ -x "$script" ]]; then
                log "Script is executable: $script"
            else
                warn "Script is not executable: $script - run: chmod +x $script"
            fi
        else
            error "Missing script: $script"
        fi
    done
}

# Run all checks
main() {
    check_environment_config
    check_docker_setup
    check_security_config
    check_monitoring_setup
    check_infrastructure
    check_cicd
    check_script_permissions
    
    echo ""
    echo "════════════════════════════════════════════════════════════════════"
    
    if [[ $ISSUES -eq 0 && $WARNINGS -eq 0 ]]; then
        echo -e "${GREEN}🎉 VALIDATION PASSED! Your DevOps Toolkit is ready for production!${NC}"
    elif [[ $ISSUES -eq 0 ]]; then
        echo -e "${YELLOW}⚠️ VALIDATION PASSED WITH WARNINGS${NC}"
        echo -e "${YELLOW}Found $WARNINGS warning(s). Consider addressing them before production.${NC}"
    else
        echo -e "${RED}❌ VALIDATION FAILED${NC}"
        echo -e "${RED}Found $ISSUES critical issue(s) and $WARNINGS warning(s).${NC}"
        echo -e "${RED}Please fix all issues before production deployment.${NC}"
        exit 1
    fi
    
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo -e "${BLUE}1. Fix any issues or warnings listed above${NC}"
    echo -e "${BLUE}2. Update .env file with your actual configuration${NC}"
    echo -e "${BLUE}3. Run: ./scripts/setup.sh to initialize the toolkit${NC}"
    echo -e "${BLUE}4. Test with: docker-compose up -d${NC}"
}

main "$@" 