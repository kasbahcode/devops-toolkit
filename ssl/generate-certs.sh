#!/bin/bash

# 🔐 SSL Certificate Generation Script
# Handles both self-signed and Let's Encrypt certificates

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default configuration
CERT_TYPE="self-signed"
DOMAIN="localhost"
EMAIL=""
OUTPUT_DIR="./ssl"
KEY_SIZE="2048"
CERT_DAYS="365"

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
🔐 SSL Certificate Generation Script

Usage: $0 [OPTIONS]

Certificate Types:
    -t, --type TYPE         Certificate type (self-signed, letsencrypt) [default: self-signed]

Options:
    -d, --domain DOMAIN     Domain name [default: localhost]
    -e, --email EMAIL       Email for Let's Encrypt (required for letsencrypt)
    -o, --output DIR        Output directory [default: ./ssl]
    -k, --key-size SIZE     Key size in bits [default: 2048]
    --days DAYS            Certificate validity in days [default: 365]
    -h, --help             Show this help message

Examples:
    $0 -t self-signed -d localhost
    $0 -t letsencrypt -d example.com -e admin@example.com
    $0 -d myapp.local --days 90
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--type)
            CERT_TYPE="$2"
            shift 2
            ;;
        -d|--domain)
            DOMAIN="$2"
            shift 2
            ;;
        -e|--email)
            EMAIL="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -k|--key-size)
            KEY_SIZE="$2"
            shift 2
            ;;
        --days)
            CERT_DAYS="$2"
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

# Validate inputs
if [[ "$CERT_TYPE" == "letsencrypt" && -z "$EMAIL" ]]; then
    error "Email is required for Let's Encrypt certificates"
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Check dependencies
check_dependencies() {
    case "$CERT_TYPE" in
        self-signed)
            if ! command -v openssl >/dev/null 2>&1; then
                error "OpenSSL is required but not installed"
            fi
            ;;
        letsencrypt)
            if ! command -v certbot >/dev/null 2>&1; then
                warn "Certbot not found. Installing..."
                install_certbot
            fi
            ;;
    esac
}

# Install certbot
install_certbot() {
    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update
        sudo apt-get install -y certbot
    elif command -v yum >/dev/null 2>&1; then
        sudo yum install -y certbot
    elif command -v brew >/dev/null 2>&1; then
        brew install certbot
    else
        error "Cannot install certbot automatically. Please install manually."
    fi
}

# Generate self-signed certificate
generate_self_signed() {
    log "🔒 Generating self-signed certificate for $DOMAIN..."
    
    local key_file="$OUTPUT_DIR/$DOMAIN.key"
    local cert_file="$OUTPUT_DIR/$DOMAIN.crt"
    local csr_file="$OUTPUT_DIR/$DOMAIN.csr"
    
    # Generate private key
    log "📝 Generating private key..."
    openssl genrsa -out "$key_file" "$KEY_SIZE"
    
    # Create certificate signing request config
    cat > "$OUTPUT_DIR/cert.conf" << EOF
[req]
default_bits = $KEY_SIZE
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = v3_req

[dn]
C=US
ST=State
L=City
O=DevOps Toolkit
OU=IT Department
CN=$DOMAIN

[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = $DOMAIN
DNS.2 = *.$DOMAIN
DNS.3 = localhost
IP.1 = 127.0.0.1
IP.2 = ::1
EOF

    # Generate certificate signing request
    log "📄 Creating certificate signing request..."
    openssl req -new -key "$key_file" -out "$csr_file" -config "$OUTPUT_DIR/cert.conf"
    
    # Generate certificate
    log "🏆 Generating certificate..."
    openssl x509 -req -in "$csr_file" -signkey "$key_file" -out "$cert_file" \
        -days "$CERT_DAYS" -extensions v3_req -extfile "$OUTPUT_DIR/cert.conf"
    
    # Set proper permissions
    chmod 600 "$key_file"
    chmod 644 "$cert_file"
    
    # Clean up
    rm -f "$csr_file" "$OUTPUT_DIR/cert.conf"
    
    log "✅ Self-signed certificate generated successfully!"
    log "🔑 Private key: $key_file"
    log "📜 Certificate: $cert_file"
    log "⏰ Valid for: $CERT_DAYS days"
    
    # Display certificate info
    info "Certificate details:"
    openssl x509 -in "$cert_file" -text -noout | grep -A 2 "Subject:"
    openssl x509 -in "$cert_file" -text -noout | grep -A 5 "X509v3 Subject Alternative Name:"
}

# Generate Let's Encrypt certificate
generate_letsencrypt() {
    log "🔒 Generating Let's Encrypt certificate for $DOMAIN..."
    
    # Check if domain is reachable
    if ! ping -c 1 "$DOMAIN" >/dev/null 2>&1; then
        warn "Domain $DOMAIN may not be reachable. Ensure DNS is configured properly."
    fi
    
    # Generate certificate using certbot
    if certbot certonly \
        --standalone \
        --non-interactive \
        --agree-tos \
        --email "$EMAIL" \
        --domains "$DOMAIN" \
        --cert-path "$OUTPUT_DIR/$DOMAIN.crt" \
        --key-path "$OUTPUT_DIR/$DOMAIN.key" \
        --fullchain-path "$OUTPUT_DIR/$DOMAIN-fullchain.crt"; then
        
        log "✅ Let's Encrypt certificate generated successfully!"
        log "🔑 Private key: $OUTPUT_DIR/$DOMAIN.key"
        log "📜 Certificate: $OUTPUT_DIR/$DOMAIN.crt"
        log "🔗 Full chain: $OUTPUT_DIR/$DOMAIN-fullchain.crt"
        log "⏰ Valid for: 90 days (auto-renewal recommended)"
        
        # Set up auto-renewal reminder
        info "Setting up renewal reminder..."
        create_renewal_script
    else
        error "Failed to generate Let's Encrypt certificate. Check domain and DNS configuration."
    fi
}

# Create certificate renewal script
create_renewal_script() {
    local renewal_script="$OUTPUT_DIR/renew-cert.sh"
    
    cat > "$renewal_script" << 'EOF'
#!/bin/bash
# SSL Certificate Renewal Script

log() {
    echo "[$(date)] $1"
}

log "Checking certificate renewal for DOMAIN_PLACEHOLDER..."

if certbot renew --quiet --cert-name DOMAIN_PLACEHOLDER; then
    log "Certificate renewed successfully"
    
    # Restart services if needed
    if command -v docker-compose >/dev/null 2>&1; then
        log "Restarting Docker services..."
        docker-compose restart nginx || true
    fi
    
    if command -v systemctl >/dev/null 2>&1; then
        log "Restarting nginx..."
        sudo systemctl reload nginx || true
    fi
else
    log "Certificate renewal failed or not needed"
fi
EOF

    # Replace placeholder with actual domain
    sed -i.bak "s/DOMAIN_PLACEHOLDER/$DOMAIN/g" "$renewal_script"
    rm -f "${renewal_script}.bak"
    
    chmod +x "$renewal_script"
    
    log "📅 Renewal script created: $renewal_script"
    info "Add to crontab for automatic renewal: 0 3 * * * $renewal_script"
}

# Generate DH parameters for better security
generate_dhparam() {
    local dhparam_file="$OUTPUT_DIR/dhparam.pem"
    
    if [[ ! -f "$dhparam_file" ]]; then
        log "🔐 Generating DH parameters (this may take a while)..."
        openssl dhparam -out "$dhparam_file" 2048
        log "✅ DH parameters generated: $dhparam_file"
    else
        log "✅ DH parameters already exist: $dhparam_file"
    fi
}

# Create nginx SSL configuration snippet
create_nginx_config() {
    local nginx_config="$OUTPUT_DIR/nginx-ssl.conf"
    
    cat > "$nginx_config" << EOF
# SSL Configuration for Nginx
# Include this in your server block

ssl_certificate $OUTPUT_DIR/$DOMAIN.crt;
ssl_certificate_key $OUTPUT_DIR/$DOMAIN.key;

# SSL Security
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA384;
ssl_prefer_server_ciphers on;

# DH Parameters
ssl_dhparam $OUTPUT_DIR/dhparam.pem;

# SSL Session
ssl_session_cache shared:SSL:10m;
ssl_session_timeout 10m;

# HSTS (optional - enable for production)
# add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

# SSL Stapling (for Let's Encrypt)
ssl_stapling on;
ssl_stapling_verify on;
ssl_trusted_certificate $OUTPUT_DIR/$DOMAIN-fullchain.crt;
resolver 8.8.8.8 8.8.4.4 valid=300s;
resolver_timeout 5s;
EOF

    log "📋 Nginx SSL configuration created: $nginx_config"
}

# Verify certificate
verify_certificate() {
    local cert_file="$OUTPUT_DIR/$DOMAIN.crt"
    local key_file="$OUTPUT_DIR/$DOMAIN.key"
    
    if [[ -f "$cert_file" && -f "$key_file" ]]; then
        log "🔍 Verifying certificate..."
        
        # Check certificate validity
        if openssl x509 -in "$cert_file" -noout -checkend 86400; then
            log "✅ Certificate is valid and not expiring within 24 hours"
        else
            warn "⚠️ Certificate expires within 24 hours!"
        fi
        
        # Verify key and certificate match
        local cert_hash=$(openssl x509 -in "$cert_file" -noout -pubkey | openssl md5)
        local key_hash=$(openssl rsa -in "$key_file" -noout -pubout | openssl md5)
        
        if [[ "$cert_hash" == "$key_hash" ]]; then
            log "✅ Certificate and private key match"
        else
            error "❌ Certificate and private key do not match!"
        fi
        
        # Display certificate expiration
        local expiry=$(openssl x509 -in "$cert_file" -noout -enddate | cut -d= -f2)
        log "📅 Certificate expires: $expiry"
    else
        error "Certificate files not found"
    fi
}

# Main execution
main() {
    log "🔐 Starting SSL certificate generation..."
    log "Type: $CERT_TYPE"
    log "Domain: $DOMAIN"
    log "Output: $OUTPUT_DIR"
    
    check_dependencies
    
    case "$CERT_TYPE" in
        self-signed)
            generate_self_signed
            generate_dhparam
            ;;
        letsencrypt)
            generate_letsencrypt
            generate_dhparam
            ;;
        *)
            error "Unknown certificate type: $CERT_TYPE"
            ;;
    esac
    
    create_nginx_config
    verify_certificate
    
    log "🎉 SSL certificate generation completed!"
    log ""
    log "📋 Next steps:"
    log "1. Configure your web server to use the certificates"
    log "2. Test SSL configuration with: openssl s_client -connect $DOMAIN:443"
    log "3. For Let's Encrypt, set up automatic renewal"
    log ""
    log "📁 Generated files:"
    ls -la "$OUTPUT_DIR"/*.{crt,key,pem,conf} 2>/dev/null || true
}

# Run main function
main "$@" 