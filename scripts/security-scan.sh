#!/bin/bash

# 🔒 Security Scanning Script
# Multi-tool security scanning with real vulnerability detection

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SCAN_TARGET="."
OUTPUT_DIR="security-reports"
SEVERITY_FILTER="HIGH,CRITICAL"
SCAN_TYPES=()
FAIL_ON_HIGH="false"

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

# Usage function
usage() {
    cat << EOF
🔒 Security Scanning Script

Usage: $0 [OPTIONS]

Scan Types:
    --trivy            Container and filesystem vulnerability scanning
    --semgrep          Static analysis for code vulnerabilities
    --hadolint         Dockerfile best practices
    --checkov          Infrastructure as code security
    --secrets          Secret detection in code
    --all              Run all available scans

Options:
    -t, --target PATH       Target to scan [default: .]
    -o, --output DIR        Output directory [default: security-reports]
    -s, --severity LEVEL    Severity filter (LOW,MEDIUM,HIGH,CRITICAL) [default: HIGH,CRITICAL]
    --fail-on-high         Exit with error if HIGH/CRITICAL issues found
    -h, --help             Show this help message

Examples:
    $0 --trivy --semgrep
    $0 --all --fail-on-high
    $0 --target /path/to/project --output /tmp/security
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --trivy|--semgrep|--hadolint|--checkov|--secrets)
            SCAN_TYPES+=("${1#--}")
            shift
            ;;
        --all)
            SCAN_TYPES=("trivy" "semgrep" "hadolint" "checkov" "secrets")
            shift
            ;;
        -t|--target)
            SCAN_TARGET="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -s|--severity)
            SEVERITY_FILTER="$2"
            shift 2
            ;;
        --fail-on-high)
            FAIL_ON_HIGH="true"
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

# Default to all scans if none specified
if [[ ${#SCAN_TYPES[@]} -eq 0 ]]; then
    SCAN_TYPES=("trivy" "semgrep" "hadolint" "checkov" "secrets")
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Check if tools are available
check_tool() {
    local tool="$1"
    if ! command -v "$tool" >/dev/null 2>&1; then
        warn "$tool not found, skipping scan. Install with: $2"
        return 1
    fi
    return 0
}

# Install missing tools (where possible)
install_tools() {
    log "🔧 Checking for required security tools..."
    
    # Trivy
    if [[ " ${SCAN_TYPES[*]} " =~ " trivy " ]] && ! command -v trivy >/dev/null 2>&1; then
        if command -v brew >/dev/null 2>&1; then
            log "Installing Trivy via Homebrew..."
            brew install trivy
        elif command -v apt >/dev/null 2>&1; then
            log "Installing Trivy via apt..."
            sudo apt-get update && sudo apt-get install -y wget apt-transport-https gnupg lsb-release
            wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
            echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
            sudo apt-get update && sudo apt-get install trivy
        else
            warn "Cannot auto-install Trivy. Please install manually: https://aquasecurity.github.io/trivy/"
        fi
    fi
    
    # Semgrep
    if [[ " ${SCAN_TYPES[*]} " =~ " semgrep " ]] && ! command -v semgrep >/dev/null 2>&1; then
        if command -v pip3 >/dev/null 2>&1; then
            log "Installing Semgrep via pip..."
            pip3 install semgrep
        else
            warn "Cannot install Semgrep. Install with: pip3 install semgrep"
        fi
    fi
    
    # Hadolint
    if [[ " ${SCAN_TYPES[*]} " =~ " hadolint " ]] && ! command -v hadolint >/dev/null 2>&1; then
        if command -v brew >/dev/null 2>&1; then
            log "Installing Hadolint via Homebrew..."
            brew install hadolint
        else
            warn "Cannot install Hadolint. Install with: brew install hadolint"
        fi
    fi
    
    # TruffleHog for secrets
    if [[ " ${SCAN_TYPES[*]} " =~ " secrets " ]] && ! command -v trufflehog >/dev/null 2>&1; then
        if command -v brew >/dev/null 2>&1; then
            log "Installing TruffleHog via Homebrew..."
            brew install trufflehog
        else
            warn "Cannot install TruffleHog. Install with: brew install trufflehog"
        fi
    fi
    
    # Checkov
    if [[ " ${SCAN_TYPES[*]} " =~ " checkov " ]] && ! command -v checkov >/dev/null 2>&1; then
        if command -v pip3 >/dev/null 2>&1; then
            log "Installing Checkov via pip..."
            pip3 install checkov
        else
            warn "Cannot install Checkov. Install with: pip3 install checkov"
        fi
    fi
}

# Run Trivy scan
run_trivy() {
    log "🔍 Running Trivy vulnerability scan..."
    
    local report_file="$OUTPUT_DIR/trivy-report.json"
    local summary_file="$OUTPUT_DIR/trivy-summary.txt"
    
    # Filesystem scan
    if trivy fs --format json --output "$report_file" --severity "$SEVERITY_FILTER" "$SCAN_TARGET"; then
        log "✅ Trivy filesystem scan completed"
        
        # Generate human-readable summary
        trivy fs --format table --severity "$SEVERITY_FILTER" "$SCAN_TARGET" > "$summary_file"
        
        # Check for critical/high vulnerabilities
        local critical_count=$(jq -r '.Results[]?.Vulnerabilities[]? | select(.Severity == "CRITICAL") | .VulnerabilityID' "$report_file" 2>/dev/null | wc -l)
        local high_count=$(jq -r '.Results[]?.Vulnerabilities[]? | select(.Severity == "HIGH") | .VulnerabilityID' "$report_file" 2>/dev/null | wc -l)
        
        if [[ $critical_count -gt 0 || $high_count -gt 0 ]]; then
            warn "Found $critical_count CRITICAL and $high_count HIGH vulnerabilities"
            if [[ "$FAIL_ON_HIGH" == "true" ]]; then
                error "Security scan failed due to high-severity vulnerabilities"
            fi
        else
            log "✅ No high-severity vulnerabilities found"
        fi
    else
        warn "Trivy scan failed or found issues"
    fi
    
    # Docker image scan (if Dockerfile exists)
    if [[ -f "$SCAN_TARGET/Dockerfile" ]]; then
        log "🐳 Scanning Dockerfile with Trivy..."
        trivy config --format table --severity "$SEVERITY_FILTER" "$SCAN_TARGET/Dockerfile" > "$OUTPUT_DIR/trivy-dockerfile.txt"
    fi
}

# Run Semgrep scan
run_semgrep() {
    log "🔍 Running Semgrep static analysis..."
    
    local report_file="$OUTPUT_DIR/semgrep-report.json"
    local summary_file="$OUTPUT_DIR/semgrep-summary.txt"
    
    if semgrep --config=auto --json --output="$report_file" "$SCAN_TARGET"; then
        log "✅ Semgrep scan completed"
        
        # Generate summary
        semgrep --config=auto --text "$SCAN_TARGET" > "$summary_file" 2>&1 || true
        
        # Check for high-severity findings
        local findings_count=$(jq -r '.results | length' "$report_file" 2>/dev/null || echo "0")
        if [[ $findings_count -gt 0 ]]; then
            warn "Semgrep found $findings_count potential security issues"
        else
            log "✅ No security issues found by Semgrep"
        fi
    else
        warn "Semgrep scan encountered issues"
    fi
}

# Run Hadolint scan
run_hadolint() {
    log "🐳 Running Hadolint Dockerfile analysis..."
    
    local dockerfile="$SCAN_TARGET/Dockerfile"
    if [[ ! -f "$dockerfile" ]]; then
        warn "No Dockerfile found, skipping Hadolint scan"
        return
    fi
    
    local report_file="$OUTPUT_DIR/hadolint-report.json"
    local summary_file="$OUTPUT_DIR/hadolint-summary.txt"
    
    if hadolint --format json "$dockerfile" > "$report_file" 2>&1; then
        log "✅ Hadolint scan completed"
        hadolint --format tty "$dockerfile" > "$summary_file" 2>&1 || true
    else
        # Hadolint exits with error if it finds issues, which is expected
        hadolint --format tty "$dockerfile" > "$summary_file" 2>&1 || true
        warn "Hadolint found Dockerfile best practice violations"
    fi
}

# Run Checkov scan
run_checkov() {
    log "🏗️ Running Checkov infrastructure scan..."
    
    local report_file="$OUTPUT_DIR/checkov-report.json"
    local summary_file="$OUTPUT_DIR/checkov-summary.txt"
    
    if checkov -d "$SCAN_TARGET" --output json --output-file "$report_file" --quiet; then
        log "✅ Checkov scan completed"
        checkov -d "$SCAN_TARGET" --output cli > "$summary_file" 2>&1 || true
    else
        warn "Checkov found infrastructure security issues"
        checkov -d "$SCAN_TARGET" --output cli > "$summary_file" 2>&1 || true
    fi
}

# Run secrets detection
run_secrets_scan() {
    log "🔐 Running secrets detection..."
    
    local report_file="$OUTPUT_DIR/secrets-report.json"
    local summary_file="$OUTPUT_DIR/secrets-summary.txt"
    
    if command -v trufflehog >/dev/null 2>&1; then
        if trufflehog filesystem "$SCAN_TARGET" --json > "$report_file" 2>&1; then
            log "✅ Secrets scan completed"
            
            # Generate summary
            local secrets_count=$(grep -c '{}' "$report_file" 2>/dev/null || echo "0")
            if [[ $secrets_count -gt 0 ]]; then
                warn "Found $secrets_count potential secrets"
                trufflehog filesystem "$SCAN_TARGET" > "$summary_file" 2>&1 || true
                
                if [[ "$FAIL_ON_HIGH" == "true" ]]; then
                    error "Security scan failed due to detected secrets"
                fi
            else
                log "✅ No secrets detected"
                echo "No secrets found" > "$summary_file"
            fi
        else
            warn "Secrets scan encountered issues"
        fi
    else
        warn "TruffleHog not available for secrets detection"
    fi
}

# Generate consolidated report
generate_report() {
    log "📊 Generating consolidated security report..."
    
    local report_file="$OUTPUT_DIR/security-report.md"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    cat > "$report_file" << EOF
# Security Scan Report

**Generated:** $timestamp  
**Target:** $SCAN_TARGET  
**Severity Filter:** $SEVERITY_FILTER  

## Summary

EOF

    # Add summary for each scan type
    for scan_type in "${SCAN_TYPES[@]}"; do
        case $scan_type in
            trivy)
                if [[ -f "$OUTPUT_DIR/trivy-summary.txt" ]]; then
                    echo "### Trivy (Vulnerability Scanning)" >> "$report_file"
                    echo '```' >> "$report_file"
                    head -20 "$OUTPUT_DIR/trivy-summary.txt" >> "$report_file"
                    echo '```' >> "$report_file"
                    echo "" >> "$report_file"
                fi
                ;;
            semgrep)
                if [[ -f "$OUTPUT_DIR/semgrep-summary.txt" ]]; then
                    echo "### Semgrep (Static Analysis)" >> "$report_file"
                    echo '```' >> "$report_file"
                    head -20 "$OUTPUT_DIR/semgrep-summary.txt" >> "$report_file"
                    echo '```' >> "$report_file"
                    echo "" >> "$report_file"
                fi
                ;;
            hadolint)
                if [[ -f "$OUTPUT_DIR/hadolint-summary.txt" ]]; then
                    echo "### Hadolint (Dockerfile Analysis)" >> "$report_file"
                    echo '```' >> "$report_file"
                    cat "$OUTPUT_DIR/hadolint-summary.txt" >> "$report_file"
                    echo '```' >> "$report_file"
                    echo "" >> "$report_file"
                fi
                ;;
            checkov)
                if [[ -f "$OUTPUT_DIR/checkov-summary.txt" ]]; then
                    echo "### Checkov (Infrastructure Scanning)" >> "$report_file"
                    echo '```' >> "$report_file"
                    head -30 "$OUTPUT_DIR/checkov-summary.txt" >> "$report_file"
                    echo '```' >> "$report_file"
                    echo "" >> "$report_file"
                fi
                ;;
            secrets)
                if [[ -f "$OUTPUT_DIR/secrets-summary.txt" ]]; then
                    echo "### Secrets Detection" >> "$report_file"
                    echo '```' >> "$report_file"
                    cat "$OUTPUT_DIR/secrets-summary.txt" >> "$report_file"
                    echo '```' >> "$report_file"
                    echo "" >> "$report_file"
                fi
                ;;
        esac
    done
    
    cat >> "$report_file" << EOF

## Recommendations

1. **High/Critical Vulnerabilities:** Address immediately
2. **Secrets:** Remove any detected secrets and rotate credentials
3. **Infrastructure Issues:** Review and fix Terraform/K8s configurations
4. **Dockerfile Issues:** Follow best practices for container security

## Files Generated

- \`security-report.md\` - This consolidated report
EOF

    for scan_type in "${SCAN_TYPES[@]}"; do
        if [[ -f "$OUTPUT_DIR/${scan_type}-report.json" ]]; then
            echo "- \`${scan_type}-report.json\` - Machine-readable results" >> "$report_file"
        fi
        if [[ -f "$OUTPUT_DIR/${scan_type}-summary.txt" ]]; then
            echo "- \`${scan_type}-summary.txt\` - Human-readable summary" >> "$report_file"
        fi
    done
    
    log "✅ Consolidated report generated: $report_file"
}

# Main execution
main() {
    log "🔒 Starting security scan..."
    log "Target: $SCAN_TARGET"
    log "Scans: ${SCAN_TYPES[*]}"
    log "Output: $OUTPUT_DIR"
    
    install_tools
    
    for scan_type in "${SCAN_TYPES[@]}"; do
        case $scan_type in
            trivy)
                if check_tool trivy "brew install trivy"; then
                    run_trivy
                fi
                ;;
            semgrep)
                if check_tool semgrep "pip3 install semgrep"; then
                    run_semgrep
                fi
                ;;
            hadolint)
                if check_tool hadolint "brew install hadolint"; then
                    run_hadolint
                fi
                ;;
            checkov)
                if check_tool checkov "pip3 install checkov"; then
                    run_checkov
                fi
                ;;
            secrets)
                run_secrets_scan
                ;;
            *)
                warn "Unknown scan type: $scan_type"
                ;;
        esac
    done
    
    generate_report
    
    log "🎉 Security scan completed!"
    log "📁 Reports available in: $OUTPUT_DIR"
    
    if [[ "$FAIL_ON_HIGH" == "true" ]]; then
        info "Note: Scan will exit with error if high-severity issues were found"
    fi
}

# Run main function
main "$@" 