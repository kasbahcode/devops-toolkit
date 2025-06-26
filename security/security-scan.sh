#!/bin/bash

# 🔒 Security Scanning and Vulnerability Assessment Script
# Comprehensive security scanning for containers, code, and infrastructure

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
SCAN_TYPE="all"
OUTPUT_FORMAT="table"
OUTPUT_DIR="./security-reports"
SEVERITY_THRESHOLD="MEDIUM"
FAIL_ON_HIGH="false"
DOCKER_IMAGE=""
TARGET_DIR="."

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

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

# Usage function
usage() {
    cat << EOF
🔒 Security Scanning and Vulnerability Assessment Script

Usage: $0 [OPTIONS]

Scan Types:
    --container IMAGE      Scan Docker container image
    --code                 Scan source code for vulnerabilities
    --secrets              Scan for secrets and sensitive data
    --dependencies         Scan dependencies for vulnerabilities
    --infrastructure       Scan infrastructure as code
    --compliance           Run compliance checks
    --all                  Run all security scans

Options:
    -o, --output DIR       Output directory for reports [default: ./security-reports]
    -f, --format FORMAT    Output format (table, json, sarif) [default: table]
    -s, --severity LEVEL   Minimum severity level (LOW, MEDIUM, HIGH, CRITICAL) [default: MEDIUM]
    --fail-on-high        Exit with error code if HIGH or CRITICAL vulnerabilities found
    -t, --target DIR       Target directory to scan [default: .]
    -h, --help            Show this help message

Examples:
    $0 --container nginx:latest
    $0 --code --secrets --dependencies
    $0 --all --fail-on-high
    $0 --infrastructure --format json
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --container)
            SCAN_TYPE="container"
            DOCKER_IMAGE="$2"
            shift 2
            ;;
        --code)
            SCAN_TYPE="code"
            shift
            ;;
        --secrets)
            SCAN_TYPE="secrets"
            shift
            ;;
        --dependencies)
            SCAN_TYPE="dependencies"
            shift
            ;;
        --infrastructure)
            SCAN_TYPE="infrastructure"
            shift
            ;;
        --compliance)
            SCAN_TYPE="compliance"
            shift
            ;;
        --all)
            SCAN_TYPE="all"
            shift
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -f|--format)
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        -s|--severity)
            SEVERITY_THRESHOLD="$2"
            shift 2
            ;;
        --fail-on-high)
            FAIL_ON_HIGH="true"
            shift
            ;;
        -t|--target)
            TARGET_DIR="$2"
            shift 2
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

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install security tools
install_tools() {
    log "🔧 Installing security scanning tools..."
    
    # Install Trivy
    if ! command_exists trivy; then
        info "Installing Trivy..."
        curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
    fi
    
    # Install Semgrep
    if ! command_exists semgrep; then
        info "Installing Semgrep..."
        pip3 install semgrep
    fi
    
    # Install GitLeaks
    if ! command_exists gitleaks; then
        info "Installing GitLeaks..."
        curl -sSfL https://raw.githubusercontent.com/trufflesecurity/gitleaks/master/scripts/install.sh | sh -s -- -b /usr/local/bin
    fi
    
    # Install Safety (Python)
    if ! command_exists safety; then
        info "Installing Safety..."
        pip3 install safety
    fi
    
    # Install npm-audit (Node.js)
    if command_exists npm && ! command_exists npm-audit; then
        info "npm audit is built into npm"
    fi
    
    # Install Checkov
    if ! command_exists checkov; then
        info "Installing Checkov..."
        pip3 install checkov
    fi
    
    success "✅ Security tools installed"
}

# Container vulnerability scanning
scan_container() {
    if [[ -z "$DOCKER_IMAGE" ]]; then
        error "Docker image must be specified for container scanning"
    fi
    
    log "🐳 Scanning container image: $DOCKER_IMAGE"
    
    local output_file="$OUTPUT_DIR/container-scan-$(date +%Y%m%d_%H%M%S)"
    
    # Trivy container scan
    if command_exists trivy; then
        info "Running Trivy container scan..."
        case "$OUTPUT_FORMAT" in
            json)
                trivy image --format json --output "$output_file.json" "$DOCKER_IMAGE"
                ;;
            sarif)
                trivy image --format sarif --output "$output_file.sarif" "$DOCKER_IMAGE"
                ;;
            *)
                trivy image --format table --output "$output_file.txt" "$DOCKER_IMAGE"
                trivy image --format table "$DOCKER_IMAGE"
                ;;
        esac
        
        # Check for high/critical vulnerabilities
        if [[ "$FAIL_ON_HIGH" == "true" ]]; then
            local high_count
            high_count=$(trivy image --format json "$DOCKER_IMAGE" | jq '[.Results[]?.Vulnerabilities[]? | select(.Severity == "HIGH" or .Severity == "CRITICAL")] | length')
            if [[ "$high_count" -gt 0 ]]; then
                error "Found $high_count HIGH/CRITICAL vulnerabilities in container image"
            fi
        fi
    else
        warn "Trivy not available, skipping container scan"
    fi
    
    success "✅ Container scan completed"
}

# Source code vulnerability scanning
scan_code() {
    log "📝 Scanning source code for vulnerabilities..."
    
    local output_file="$OUTPUT_DIR/code-scan-$(date +%Y%m%d_%H%M%S)"
    
    # Semgrep scan
    if command_exists semgrep; then
        info "Running Semgrep code scan..."
        case "$OUTPUT_FORMAT" in
            json)
                semgrep --config=auto --json --output="$output_file-semgrep.json" "$TARGET_DIR"
                ;;
            sarif)
                semgrep --config=auto --sarif --output="$output_file-semgrep.sarif" "$TARGET_DIR"
                ;;
            *)
                semgrep --config=auto --output="$output_file-semgrep.txt" "$TARGET_DIR"
                semgrep --config=auto "$TARGET_DIR"
                ;;
        esac
    else
        warn "Semgrep not available, skipping code scan"
    fi
    
    # CodeQL scan (if available)
    if command_exists codeql; then
        info "Running CodeQL analysis..."
        codeql database create "$output_file-codeql-db" --language=javascript,python --source-root="$TARGET_DIR"
        codeql database analyze "$output_file-codeql-db" --format="$OUTPUT_FORMAT" --output="$output_file-codeql.$OUTPUT_FORMAT"
    fi
    
    success "✅ Code scan completed"
}

# Secrets scanning
scan_secrets() {
    log "🔐 Scanning for secrets and sensitive data..."
    
    local output_file="$OUTPUT_DIR/secrets-scan-$(date +%Y%m%d_%H%M%S)"
    
    # GitLeaks scan
    if command_exists gitleaks; then
        info "Running GitLeaks secrets scan..."
        case "$OUTPUT_FORMAT" in
            json)
                gitleaks detect --source="$TARGET_DIR" --report-format=json --report-path="$output_file-gitleaks.json" || true
                ;;
            sarif)
                gitleaks detect --source="$TARGET_DIR" --report-format=sarif --report-path="$output_file-gitleaks.sarif" || true
                ;;
            *)
                gitleaks detect --source="$TARGET_DIR" --report-format=csv --report-path="$output_file-gitleaks.csv" || true
                gitleaks detect --source="$TARGET_DIR" --verbose || true
                ;;
        esac
    else
        warn "GitLeaks not available, skipping secrets scan"
    fi
    
    # TruffleHog scan (if available)
    if command_exists trufflehog; then
        info "Running TruffleHog secrets scan..."
        trufflehog filesystem "$TARGET_DIR" --json > "$output_file-trufflehog.json" || true
    fi
    
    success "✅ Secrets scan completed"
}

# Dependencies vulnerability scanning
scan_dependencies() {
    log "📦 Scanning dependencies for vulnerabilities..."
    
    local output_file="$OUTPUT_DIR/dependencies-scan-$(date +%Y%m%d_%H%M%S)"
    
    # Node.js dependencies
    if [[ -f "$TARGET_DIR/package.json" ]]; then
        info "Scanning Node.js dependencies..."
        cd "$TARGET_DIR"
        case "$OUTPUT_FORMAT" in
            json)
                npm audit --json > "$output_file-npm.json" || true
                ;;
            *)
                npm audit > "$output_file-npm.txt" || true
                npm audit || true
                ;;
        esac
        cd - > /dev/null
    fi
    
    # Python dependencies
    if [[ -f "$TARGET_DIR/requirements.txt" ]] && command_exists safety; then
        info "Scanning Python dependencies..."
        case "$OUTPUT_FORMAT" in
            json)
                safety check --json --file "$TARGET_DIR/requirements.txt" > "$output_file-python.json" || true
                ;;
            *)
                safety check --file "$TARGET_DIR/requirements.txt" > "$output_file-python.txt" || true
                safety check --file "$TARGET_DIR/requirements.txt" || true
                ;;
        esac
    fi
    
    # Ruby dependencies (if Gemfile exists)
    if [[ -f "$TARGET_DIR/Gemfile" ]] && command_exists bundle-audit; then
        info "Scanning Ruby dependencies..."
        cd "$TARGET_DIR"
        bundle-audit check > "$output_file-ruby.txt" || true
        cd - > /dev/null
    fi
    
    # Java dependencies (if pom.xml exists)
    if [[ -f "$TARGET_DIR/pom.xml" ]] && command_exists mvn; then
        info "Scanning Java dependencies..."
        cd "$TARGET_DIR"
        mvn org.owasp:dependency-check-maven:check > "$output_file-java.txt" || true
        cd - > /dev/null
    fi
    
    success "✅ Dependencies scan completed"
}

# Infrastructure as Code scanning
scan_infrastructure() {
    log "🏗️ Scanning Infrastructure as Code..."
    
    local output_file="$OUTPUT_DIR/infrastructure-scan-$(date +%Y%m%d_%H%M%S)"
    
    # Checkov scan
    if command_exists checkov; then
        info "Running Checkov IaC scan..."
        case "$OUTPUT_FORMAT" in
            json)
                checkov --directory "$TARGET_DIR" --output json --output-file "$output_file-checkov.json" || true
                ;;
            sarif)
                checkov --directory "$TARGET_DIR" --output sarif --output-file "$output_file-checkov.sarif" || true
                ;;
            *)
                checkov --directory "$TARGET_DIR" --output cli --output-file "$output_file-checkov.txt" || true
                checkov --directory "$TARGET_DIR" || true
                ;;
        esac
    else
        warn "Checkov not available, skipping IaC scan"
    fi
    
    # Terraform security scan
    if command_exists tfsec && find "$TARGET_DIR" -name "*.tf" -type f | head -1 > /dev/null; then
        info "Running tfsec Terraform scan..."
        case "$OUTPUT_FORMAT" in
            json)
                tfsec "$TARGET_DIR" --format json --out "$output_file-tfsec.json" || true
                ;;
            sarif)
                tfsec "$TARGET_DIR" --format sarif --out "$output_file-tfsec.sarif" || true
                ;;
            *)
                tfsec "$TARGET_DIR" --out "$output_file-tfsec.txt" || true
                tfsec "$TARGET_DIR" || true
                ;;
        esac
    fi
    
    # Kubernetes security scan
    if command_exists kubesec && find "$TARGET_DIR" -name "*.yaml" -o -name "*.yml" | head -1 > /dev/null; then
        info "Running kubesec Kubernetes scan..."
        find "$TARGET_DIR" -name "*.yaml" -o -name "*.yml" | while read -r file; do
            kubesec scan "$file" > "$output_file-kubesec-$(basename "$file").json" || true
        done
    fi
    
    success "✅ Infrastructure scan completed"
}

# Compliance checks
scan_compliance() {
    log "📋 Running compliance checks..."
    
    local output_file="$OUTPUT_DIR/compliance-scan-$(date +%Y%m%d_%H%M%S)"
    
    # CIS Docker Benchmark
    if command_exists docker-bench-security; then
        info "Running CIS Docker Benchmark..."
        docker-bench-security > "$output_file-docker-bench.txt" || true
    fi
    
    # Kubernetes CIS Benchmark
    if command_exists kube-bench; then
        info "Running CIS Kubernetes Benchmark..."
        kube-bench > "$output_file-kube-bench.txt" || true
    fi
    
    # Linux CIS Benchmark
    if command_exists lynis; then
        info "Running Lynis system audit..."
        lynis audit system > "$output_file-lynis.txt" || true
    fi
    
    success "✅ Compliance checks completed"
}

# Generate security report
generate_report() {
    log "📊 Generating security report..."
    
    local report_file="$OUTPUT_DIR/security-report-$(date +%Y%m%d_%H%M%S).html"
    
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Security Scan Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background: #f0f0f0; padding: 20px; border-radius: 5px; }
        .section { margin: 20px 0; padding: 15px; border-left: 4px solid #007cba; }
        .critical { border-left-color: #d32f2f; }
        .high { border-left-color: #ff5722; }
        .medium { border-left-color: #ff9800; }
        .low { border-left-color: #4caf50; }
        .info { border-left-color: #2196f3; }
        pre { background: #f5f5f5; padding: 10px; border-radius: 3px; overflow-x: auto; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🔒 Security Scan Report</h1>
        <p><strong>Generated:</strong> $(date)</p>
        <p><strong>Target:</strong> $TARGET_DIR</p>
        <p><strong>Scan Type:</strong> $SCAN_TYPE</p>
    </div>
    
    <div class="section info">
        <h2>📋 Summary</h2>
        <p>Security scan completed successfully. Check individual scan results for detailed findings.</p>
    </div>
    
    <div class="section">
        <h2>📁 Report Files</h2>
        <ul>
EOF

    # List all generated report files
    find "$OUTPUT_DIR" -name "*-$(date +%Y%m%d)*" -type f | while read -r file; do
        echo "            <li><a href=\"$(basename "$file")\">$(basename "$file")</a></li>" >> "$report_file"
    done
    
    cat >> "$report_file" << EOF
        </ul>
    </div>
    
    <div class="section">
        <h2>🔧 Recommendations</h2>
        <ul>
            <li>Review all HIGH and CRITICAL severity findings</li>
            <li>Update vulnerable dependencies</li>
            <li>Remove any exposed secrets or credentials</li>
            <li>Apply security patches and updates</li>
            <li>Implement security best practices</li>
        </ul>
    </div>
</body>
</html>
EOF
    
    success "✅ Security report generated: $report_file"
}

# Main function
main() {
    log "🔒 Starting security scanning..."
    
    install_tools
    
    case "$SCAN_TYPE" in
        container)
            scan_container
            ;;
        code)
            scan_code
            ;;
        secrets)
            scan_secrets
            ;;
        dependencies)
            scan_dependencies
            ;;
        infrastructure)
            scan_infrastructure
            ;;
        compliance)
            scan_compliance
            ;;
        all)
            if [[ -n "$DOCKER_IMAGE" ]]; then
                scan_container
            fi
            scan_code
            scan_secrets
            scan_dependencies
            scan_infrastructure
            scan_compliance
            ;;
        *)
            error "Unknown scan type: $SCAN_TYPE"
            ;;
    esac
    
    generate_report
    
    success "🎉 Security scanning completed successfully!"
    info "📁 Reports saved to: $OUTPUT_DIR"
}

# Run main function
main "$@" 