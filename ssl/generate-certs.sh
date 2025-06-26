#!/bin/bash

# 🔒 SSL Certificate Generation and Management Script
# Generates self-signed certificates or manages Let's Encrypt certificates

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
DOMAIN=""
EMAIL=""
CERT_TYPE="self-signed"
CERT_DIR="./certs"
KEY_SIZE=4096
DAYS_VALID=365
COUNTRY="US"
STATE="CA"
CITY="San Francisco"
ORG="DevOps Toolkit"
ORG_UNIT="IT Department"

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

# Usage function
usage() {
    cat << EOF
🔒 SSL Certificate Generation and Management Script

Usage: $0 [OPTIONS]

Options:
    -d, --domain DOMAIN       Domain name for certificate
    -e, --email EMAIL         Email for Let's Encrypt
    -t, --type TYPE          Certificate type (self-signed, letsencrypt) [default: self-signed]
    --cert-dir DIR           Certificate directory [default: ./certs]
    --key-size SIZE          RSA key size [default: 4096]
    --days DAYS              Certificate validity in days [default: 365]
    --country CODE           Country code [default: US]
    --state STATE            State/Province [default: CA]
    --city CITY              City [default: San Francisco]
    --org ORG                Organization [default: DevOps Toolkit]
    --org-unit UNIT          Organizational Unit [default: IT Department]
    -h, --help               Show this help message

Examples:
    $0 -d app.example.com -t self-signed
    $0 -d app.example.com -e admin@example.com -t letsencrypt
    $0 -d "*.example.com" --key-size 2048 --days 730
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--domain)
            DOMAIN="$2"
            shift 2
            ;;
        -e|--email)
            EMAIL="$2"
            shift 2
            ;;
        -t|--type)
            CERT_TYPE="$2"
            shift 2
            ;;
        --cert-dir)
            CERT_DIR="$2"
            shift 2
            ;;
        --key-size)
            KEY_SIZE="$2"
            shift 2
            ;;
        --days)
            DAYS_VALID="$2"
            shift 2
            ;;
        --country)
            COUNTRY="$2"
            shift 2
            ;;
        --state)
            STATE="$2"
            shift 2
            ;;
        --city)
            CITY="$2"
            shift 2
            ;;
        --org)
            ORG="$2"
            shift 2
            ;;
        --org-unit)
            ORG_UNIT="$2"
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

# Validate required parameters
if [[ -z "$DOMAIN" ]]; then
    error "Domain name is required. Use -d or --domain option."
fi

if [[ "$CERT_TYPE" == "letsencrypt" && -z "$EMAIL" ]]; then
    error "Email is required for Let's Encrypt certificates. Use -e or --email option."
fi

# Create certificate directory
mkdir -p "$CERT_DIR"

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Generate self-signed certificate
generate_self_signed() {
    log "🔐 Generating self-signed certificate for $DOMAIN"
    
    local cert_file="$CERT_DIR/$DOMAIN.crt"
    local key_file="$CERT_DIR/$DOMAIN.key"
    local csr_file="$CERT_DIR/$DOMAIN.csr"
    
    # Generate private key
    log "Generating private key..."
    openssl genrsa -out "$key_file" "$KEY_SIZE"
    
    # Generate certificate signing request
    log "Generating certificate signing request..."
    openssl req -new -key "$key_file" -out "$csr_file" -subj "/C=$COUNTRY/ST=$STATE/L=$CITY/O=$ORG/OU=$ORG_UNIT/CN=$DOMAIN"
    
    # Generate self-signed certificate
    log "Generating self-signed certificate..."
    openssl x509 -req -in "$csr_file" -signkey "$key_file" -out "$cert_file" -days "$DAYS_VALID"
    
    # Create combined certificate file
    cat "$cert_file" "$key_file" > "$CERT_DIR/$DOMAIN.pem"
    
    # Set permissions
    chmod 600 "$key_file"
    chmod 644 "$cert_file"
    
    # Clean up CSR
    rm "$csr_file"
    
    log "✅ Self-signed certificate generated successfully!"
    log "📁 Certificate: $cert_file"
    log "🔑 Private key: $key_file"
    log "📋 Combined: $CERT_DIR/$DOMAIN.pem"
}

# Generate Let's Encrypt certificate
generate_letsencrypt() {
    log "🌐 Generating Let's Encrypt certificate for $DOMAIN"
    
    # Check if certbot is installed
    if ! command_exists certbot; then
        log "Installing certbot..."
        if command_exists apt-get; then
            sudo apt-get update
            sudo apt-get install -y certbot
        elif command_exists yum; then
            sudo yum install -y certbot
        elif command_exists brew; then
            brew install certbot
        else
            error "Cannot install certbot. Please install it manually."
        fi
    fi
    
    # Generate certificate
    log "Requesting certificate from Let's Encrypt..."
    sudo certbot certonly \
        --standalone \
        --email "$EMAIL" \
        --agree-tos \
        --no-eff-email \
        --domains "$DOMAIN"
    
    # Copy certificates to our directory
    local le_cert_dir="/etc/letsencrypt/live/$DOMAIN"
    if [[ -d "$le_cert_dir" ]]; then
        sudo cp "$le_cert_dir/fullchain.pem" "$CERT_DIR/$DOMAIN.crt"
        sudo cp "$le_cert_dir/privkey.pem" "$CERT_DIR/$DOMAIN.key"
        sudo cp "$le_cert_dir/fullchain.pem" "$CERT_DIR/$DOMAIN.pem"
        cat "$CERT_DIR/$DOMAIN.key" >> "$CERT_DIR/$DOMAIN.pem"
        
        # Set ownership and permissions
        sudo chown $USER:$USER "$CERT_DIR"/*
        chmod 600 "$CERT_DIR/$DOMAIN.key"
        chmod 644 "$CERT_DIR/$DOMAIN.crt"
        
        log "✅ Let's Encrypt certificate generated successfully!"
        log "📁 Certificate: $CERT_DIR/$DOMAIN.crt"
        log "🔑 Private key: $CERT_DIR/$DOMAIN.key"
        log "📋 Combined: $CERT_DIR/$DOMAIN.pem"
    else
        error "Let's Encrypt certificate generation failed"
    fi
}

# Verify certificate
verify_certificate() {
    log "🔍 Verifying certificate..."
    
    local cert_file="$CERT_DIR/$DOMAIN.crt"
    
    if [[ -f "$cert_file" ]]; then
        echo "Certificate Details:"
        openssl x509 -in "$cert_file" -text -noout | grep -E "(Subject:|Issuer:|Not Before:|Not After :)"
        
        echo ""
        echo "Certificate fingerprint:"
        openssl x509 -in "$cert_file" -fingerprint -noout
        
        # Check if certificate is valid
        if openssl x509 -in "$cert_file" -checkend 86400 >/dev/null; then
            log "✅ Certificate is valid for at least 24 hours"
        else
            warn "⚠️ Certificate expires within 24 hours"
        fi
    else
        error "Certificate file not found: $cert_file"
    fi
}

# Create Docker Compose configuration for HTTPS
create_docker_config() {
    log "🐳 Creating Docker Compose configuration..."
    
    cat > "$CERT_DIR/docker-compose.https.yml" << EOF
version: '3.8'

services:
  nginx-ssl:
    image: nginx:alpine
    container_name: nginx-ssl
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./$DOMAIN.crt:/etc/ssl/certs/$DOMAIN.crt
      - ./$DOMAIN.key:/etc/ssl/private/$DOMAIN.key
    restart: unless-stopped
    networks:
      - app-network

networks:
  app-network:
    external: true
EOF

    # Create Nginx configuration
    cat > "$CERT_DIR/nginx.conf" << EOF
events {
    worker_connections 1024;
}

http {
    upstream app {
        server app:3000;
    }

    # Redirect HTTP to HTTPS
    server {
        listen 80;
        server_name $DOMAIN;
        return 301 https://\$server_name\$request_uri;
    }

    # HTTPS server
    server {
        listen 443 ssl http2;
        server_name $DOMAIN;

        ssl_certificate /etc/ssl/certs/$DOMAIN.crt;
        ssl_certificate_key /etc/ssl/private/$DOMAIN.key;
        
        # SSL configuration
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384;
        ssl_prefer_server_ciphers off;
        ssl_session_cache shared:SSL:10m;
        ssl_session_timeout 10m;

        location / {
            proxy_pass http://app;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }
    }
}
EOF
    
    log "✅ Docker configuration created: $CERT_DIR/docker-compose.https.yml"
}

# Create Kubernetes TLS secret
create_k8s_secret() {
    log "☸️ Creating Kubernetes TLS secret..."
    
    if command_exists kubectl; then
        kubectl create secret tls "$DOMAIN-tls" \
            --cert="$CERT_DIR/$DOMAIN.crt" \
            --key="$CERT_DIR/$DOMAIN.key" \
            --dry-run=client -o yaml > "$CERT_DIR/$DOMAIN-tls-secret.yaml"
        
        log "✅ Kubernetes TLS secret manifest created: $CERT_DIR/$DOMAIN-tls-secret.yaml"
        log "Apply with: kubectl apply -f $CERT_DIR/$DOMAIN-tls-secret.yaml"
    else
        warn "kubectl not found, skipping Kubernetes secret creation"
    fi
}

# Main function
main() {
    log "🔒 Starting SSL certificate generation..."
    log "Domain: $DOMAIN"
    log "Type: $CERT_TYPE"
    log "Directory: $CERT_DIR"
    
    case "$CERT_TYPE" in
        self-signed)
            generate_self_signed
            ;;
        letsencrypt)
            generate_letsencrypt
            ;;
        *)
            error "Unknown certificate type: $CERT_TYPE"
            ;;
    esac
    
    verify_certificate
    create_docker_config
    create_k8s_secret
    
    log "🎉 SSL certificate setup completed successfully!"
    log ""
    log "📋 Next steps:"
    log "1. Use the certificates in your web server configuration"
    log "2. For Docker: docker-compose -f $CERT_DIR/docker-compose.https.yml up -d"
    log "3. For Kubernetes: kubectl apply -f $CERT_DIR/$DOMAIN-tls-secret.yaml"
    log "4. Update your DNS to point to your server"
    log "5. Test with: curl -k https://$DOMAIN"
}

# Run main function
main "$@" 