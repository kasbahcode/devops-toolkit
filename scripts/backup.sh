#!/bin/bash

# 🗄️ Backup and Restore Script
# Handles automated backups of databases, volumes, and application data

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
BACKUP_DIR="/backup"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
RETENTION_DAYS=30
S3_BUCKET=""
ENCRYPTION_KEY=""
COMPRESS="true"

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
🗄️ Backup and Restore Script

Usage: $0 [COMMAND] [OPTIONS]

Commands:
    backup          Create backup
    restore         Restore from backup
    list           List available backups
    cleanup        Clean old backups
    test           Test backup integrity

Backup Types:
    --postgres     Backup PostgreSQL databases
    --mysql        Backup MySQL databases
    --redis        Backup Redis data
    --volumes      Backup Docker volumes
    --files        Backup file directories
    --k8s          Backup Kubernetes resources
    --all          Backup everything

Options:
    -d, --dir DIR          Backup directory [default: /backup]
    -r, --retention DAYS   Retention period in days [default: 30]
    -s, --s3 BUCKET       S3 bucket for remote backup
    -e, --encrypt KEY      Encryption key for backups
    --no-compress         Disable compression
    -h, --help            Show this help message

Examples:
    $0 backup --postgres --volumes
    $0 backup --all -s my-backup-bucket
    $0 restore --postgres backup_20231201_120000
    $0 cleanup --retention 7
EOF
}

# Parse command line arguments
COMMAND=""
BACKUP_TYPES=()
while [[ $# -gt 0 ]]; do
    case $1 in
        backup|restore|list|cleanup|test)
            COMMAND="$1"
            shift
            ;;
        --postgres|--mysql|--redis|--volumes|--files|--k8s|--all)
            BACKUP_TYPES+=("${1#--}")
            shift
            ;;
        -d|--dir)
            BACKUP_DIR="$2"
            shift 2
            ;;
        -r|--retention)
            RETENTION_DAYS="$2"
            shift 2
            ;;
        -s|--s3)
            S3_BUCKET="$2"
            shift 2
            ;;
        -e|--encrypt)
            ENCRYPTION_KEY="$2"
            shift 2
            ;;
        --no-compress)
            COMPRESS="false"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            if [[ -z "$RESTORE_FILE" && "$COMMAND" == "restore" ]]; then
                RESTORE_FILE="$1"
                shift
            else
                error "Unknown option: $1"
            fi
            ;;
    esac
done

# Default command and backup types
if [[ -z "$COMMAND" ]]; then
    COMMAND="backup"
fi

if [[ ${#BACKUP_TYPES[@]} -eq 0 ]]; then
    BACKUP_TYPES=("all")
fi

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Check required tools
check_dependencies() {
    local deps=("tar" "gzip")
    
    if [[ " ${BACKUP_TYPES[*]} " =~ " postgres " || " ${BACKUP_TYPES[*]} " =~ " all " ]]; then
        deps+=("pg_dump")
    fi
    
    if [[ " ${BACKUP_TYPES[*]} " =~ " mysql " || " ${BACKUP_TYPES[*]} " =~ " all " ]]; then
        deps+=("mysqldump")
    fi
    
    if [[ " ${BACKUP_TYPES[*]} " =~ " redis " || " ${BACKUP_TYPES[*]} " =~ " all " ]]; then
        deps+=("redis-cli")
    fi
    
    if [[ " ${BACKUP_TYPES[*]} " =~ " k8s " || " ${BACKUP_TYPES[*]} " =~ " all " ]]; then
        deps+=("kubectl")
    fi
    
    if [[ -n "$S3_BUCKET" ]]; then
        deps+=("aws")
    fi
    
    if [[ -n "$ENCRYPTION_KEY" ]]; then
        deps+=("openssl")
    fi
    
    for cmd in "${deps[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            error "$cmd is required but not installed"
        fi
    done
}

# Backup PostgreSQL databases
backup_postgres() {
    log "🐘 Backing up PostgreSQL databases..."
    
    local backup_file="$BACKUP_DIR/postgres_${TIMESTAMP}.sql"
    
    # Get database list
    local databases
    if command -v docker >/dev/null 2>&1 && docker ps --format "{{.Names}}" | grep -q postgres; then
        # Docker PostgreSQL
        local container=$(docker ps --format "{{.Names}}" | grep postgres | head -1)
        databases=$(docker exec "$container" psql -U postgres -t -c "SELECT datname FROM pg_database WHERE datistemplate = false;" | grep -v "^$" | tr -d ' ')
        
        for db in $databases; do
            log "Backing up database: $db"
            docker exec "$container" pg_dump -U postgres "$db" >> "$backup_file"
            echo -e "\n-- END OF DATABASE $db --\n" >> "$backup_file"
        done
    else
        # Native PostgreSQL
        databases=$(psql -U postgres -t -c "SELECT datname FROM pg_database WHERE datistemplate = false;" | grep -v "^$" | tr -d ' ')
        
        for db in $databases; do
            log "Backing up database: $db"
            pg_dump -U postgres "$db" >> "$backup_file"
            echo -e "\n-- END OF DATABASE $db --\n" >> "$backup_file"
        done
    fi
    
    if [[ "$COMPRESS" == "true" ]]; then
        gzip "$backup_file"
        backup_file="${backup_file}.gz"
    fi
    
    log "✅ PostgreSQL backup saved: $(basename "$backup_file")"
    echo "$backup_file"
}

# Backup MySQL databases
backup_mysql() {
    log "🐬 Backing up MySQL databases..."
    
    local backup_file="$BACKUP_DIR/mysql_${TIMESTAMP}.sql"
    local mysql_opts="--single-transaction --routines --triggers"
    
    if command -v docker >/dev/null 2>&1 && docker ps --format "{{.Names}}" | grep -q mysql; then
        # Docker MySQL
        local container=$(docker ps --format "{{.Names}}" | grep mysql | head -1)
        docker exec "$container" mysqldump $mysql_opts --all-databases > "$backup_file"
    else
        # Native MySQL
        mysqldump $mysql_opts --all-databases > "$backup_file"
    fi
    
    if [[ "$COMPRESS" == "true" ]]; then
        gzip "$backup_file"
        backup_file="${backup_file}.gz"
    fi
    
    log "✅ MySQL backup saved: $(basename "$backup_file")"
    echo "$backup_file"
}

# Backup Redis data
backup_redis() {
    log "🔴 Backing up Redis data..."
    
    local backup_file="$BACKUP_DIR/redis_${TIMESTAMP}.rdb"
    
    if command -v docker >/dev/null 2>&1 && docker ps --format "{{.Names}}" | grep -q redis; then
        # Docker Redis
        local container=$(docker ps --format "{{.Names}}" | grep redis | head -1)
        docker exec "$container" redis-cli BGSAVE
        sleep 2  # Wait for background save to complete
        docker cp "$container:/data/dump.rdb" "$backup_file"
    else
        # Native Redis
        redis-cli BGSAVE
        sleep 2
        cp /var/lib/redis/dump.rdb "$backup_file"
    fi
    
    if [[ "$COMPRESS" == "true" ]]; then
        gzip "$backup_file"
        backup_file="${backup_file}.gz"
    fi
    
    log "✅ Redis backup saved: $(basename "$backup_file")"
    echo "$backup_file"
}

# Backup Docker volumes
backup_volumes() {
    log "📦 Backing up Docker volumes..."
    
    local volumes_dir="$BACKUP_DIR/volumes_${TIMESTAMP}"
    mkdir -p "$volumes_dir"
    
    # Get list of volumes
    local volumes
    volumes=$(docker volume ls -q)
    
    for volume in $volumes; do
        log "Backing up volume: $volume"
        local volume_backup="$volumes_dir/${volume}.tar"
        
        # Create temporary container to access volume
        docker run --rm \
            -v "$volume:/volume" \
            -v "$volumes_dir:/backup" \
            alpine tar -czf "/backup/${volume}.tar.gz" -C /volume .
    done
    
    # Create archive of all volumes
    local backup_file="$BACKUP_DIR/volumes_${TIMESTAMP}.tar"
    tar -cf "$backup_file" -C "$BACKUP_DIR" "volumes_${TIMESTAMP}"
    rm -rf "$volumes_dir"
    
    if [[ "$COMPRESS" == "true" ]]; then
        gzip "$backup_file"
        backup_file="${backup_file}.gz"
    fi
    
    log "✅ Docker volumes backup saved: $(basename "$backup_file")"
    echo "$backup_file"
}

# Backup file directories
backup_files() {
    log "📁 Backing up file directories..."
    
    local backup_file="$BACKUP_DIR/files_${TIMESTAMP}.tar"
    local dirs_to_backup=(
        "/etc"
        "/var/log"
        "/home"
        "/opt"
    )
    
    # Filter existing directories
    local existing_dirs=()
    for dir in "${dirs_to_backup[@]}"; do
        if [[ -d "$dir" ]]; then
            existing_dirs+=("$dir")
        fi
    done
    
    if [[ ${#existing_dirs[@]} -gt 0 ]]; then
        tar -cf "$backup_file" "${existing_dirs[@]}" 2>/dev/null || warn "Some files could not be backed up (permissions)"
        
        if [[ "$COMPRESS" == "true" ]]; then
            gzip "$backup_file"
            backup_file="${backup_file}.gz"
        fi
        
        log "✅ Files backup saved: $(basename "$backup_file")"
        echo "$backup_file"
    else
        warn "No directories found to backup"
    fi
}

# Backup Kubernetes resources
backup_k8s() {
    log "☸️ Backing up Kubernetes resources..."
    
    if ! kubectl cluster-info >/dev/null 2>&1; then
        warn "Kubernetes cluster not accessible, skipping K8s backup"
        return
    fi
    
    local k8s_dir="$BACKUP_DIR/k8s_${TIMESTAMP}"
    mkdir -p "$k8s_dir"
    
    # Backup different resource types
    local resources=(
        "deployments"
        "services"
        "configmaps"
        "secrets"
        "ingresses"
        "persistentvolumes"
        "persistentvolumeclaims"
        "namespaces"
    )
    
    for resource in "${resources[@]}"; do
        log "Backing up $resource..."
        kubectl get "$resource" --all-namespaces -o yaml > "$k8s_dir/${resource}.yaml" 2>/dev/null || warn "Could not backup $resource"
    done
    
    # Create archive
    local backup_file="$BACKUP_DIR/k8s_${TIMESTAMP}.tar"
    tar -cf "$backup_file" -C "$BACKUP_DIR" "k8s_${TIMESTAMP}"
    rm -rf "$k8s_dir"
    
    if [[ "$COMPRESS" == "true" ]]; then
        gzip "$backup_file"
        backup_file="${backup_file}.gz"
    fi
    
    log "✅ Kubernetes backup saved: $(basename "$backup_file")"
    echo "$backup_file"
}

# Encrypt backup file
encrypt_backup() {
    local file="$1"
    local encrypted_file="${file}.enc"
    
    log "🔐 Encrypting backup: $(basename "$file")"
    openssl enc -aes-256-cbc -salt -in "$file" -out "$encrypted_file" -pass pass:"$ENCRYPTION_KEY"
    rm "$file"
    echo "$encrypted_file"
}

# Upload to S3
upload_to_s3() {
    local file="$1"
    local s3_key="backups/$(basename "$file")"
    
    log "☁️ Uploading to S3: $S3_BUCKET/$s3_key"
    aws s3 cp "$file" "s3://$S3_BUCKET/$s3_key"
    
    log "✅ Uploaded to S3: $s3_key"
}

# Create backup
create_backup() {
    log "🚀 Starting backup process..."
    check_dependencies
    
    local backup_files=()
    
    # Determine what to backup
    local types_to_backup=("${BACKUP_TYPES[@]}")
    if [[ " ${types_to_backup[*]} " =~ " all " ]]; then
        types_to_backup=("postgres" "mysql" "redis" "volumes" "files" "k8s")
    fi
    
    # Perform backups
    for type in "${types_to_backup[@]}"; do
        case "$type" in
            postgres)
                if command -v pg_dump >/dev/null 2>&1 || (command -v docker >/dev/null 2>&1 && docker ps --format "{{.Names}}" | grep -q postgres); then
                    backup_files+=($(backup_postgres))
                fi
                ;;
            mysql)
                if command -v mysqldump >/dev/null 2>&1 || (command -v docker >/dev/null 2>&1 && docker ps --format "{{.Names}}" | grep -q mysql); then
                    backup_files+=($(backup_mysql))
                fi
                ;;
            redis)
                if command -v redis-cli >/dev/null 2>&1 || (command -v docker >/dev/null 2>&1 && docker ps --format "{{.Names}}" | grep -q redis); then
                    backup_files+=($(backup_redis))
                fi
                ;;
            volumes)
                if command -v docker >/dev/null 2>&1; then
                    backup_files+=($(backup_volumes))
                fi
                ;;
            files)
                backup_files+=($(backup_files))
                ;;
            k8s)
                if command -v kubectl >/dev/null 2>&1; then
                    backup_files+=($(backup_k8s))
                fi
                ;;
        esac
    done
    
    # Encrypt backups if key provided
    if [[ -n "$ENCRYPTION_KEY" ]]; then
        local encrypted_files=()
        for file in "${backup_files[@]}"; do
            if [[ -f "$file" ]]; then
                encrypted_files+=($(encrypt_backup "$file"))
            fi
        done
        backup_files=("${encrypted_files[@]}")
    fi
    
    # Upload to S3 if configured
    if [[ -n "$S3_BUCKET" ]]; then
        for file in "${backup_files[@]}"; do
            if [[ -f "$file" ]]; then
                upload_to_s3 "$file"
            fi
        done
    fi
    
    # Create backup manifest
    local manifest_file="$BACKUP_DIR/backup_${TIMESTAMP}.manifest"
    {
        echo "# Backup Manifest"
        echo "# Created: $(date)"
        echo "# Types: ${types_to_backup[*]}"
        echo ""
        for file in "${backup_files[@]}"; do
            if [[ -f "$file" ]]; then
                echo "$(basename "$file"):$(stat -c%s "$file"):$(sha256sum "$file" | cut -d' ' -f1)"
            fi
        done
    } > "$manifest_file"
    
    log "✅ Backup completed successfully!"
    log "📄 Manifest: $(basename "$manifest_file")"
    log "📁 Location: $BACKUP_DIR"
    log "📊 Files created: ${#backup_files[@]}"
}

# List available backups
list_backups() {
    log "📋 Available backups in $BACKUP_DIR:"
    
    if [[ ! -d "$BACKUP_DIR" ]]; then
        warn "Backup directory does not exist: $BACKUP_DIR"
        return
    fi
    
    find "$BACKUP_DIR" -name "*.sql*" -o -name "*.tar*" -o -name "*.rdb*" -o -name "*.manifest" | sort | while read -r file; do
        local size=$(du -h "$file" | cut -f1)
        local date=$(date -r "$file" "+%Y-%m-%d %H:%M:%S")
        echo "  $(basename "$file") ($size) - $date"
    done
}

# Clean old backups
cleanup_backups() {
    log "🧹 Cleaning backups older than $RETENTION_DAYS days..."
    
    if [[ ! -d "$BACKUP_DIR" ]]; then
        warn "Backup directory does not exist: $BACKUP_DIR"
        return
    fi
    
    local deleted_count=0
    find "$BACKUP_DIR" -type f -mtime +$RETENTION_DAYS | while read -r file; do
        log "Deleting old backup: $(basename "$file")"
        rm "$file"
        ((deleted_count++))
    done
    
    log "✅ Cleanup completed. Deleted $deleted_count files."
}

# Test backup integrity
test_backup() {
    log "🔍 Testing backup integrity..."
    
    # Check if backup files exist and are readable
    local backup_count=0
    local corrupt_count=0
    
    for file in "$BACKUP_DIR"/*.{sql,tar,rdb}*; do
        if [[ -f "$file" ]]; then
            backup_count=$((backup_count + 1))
            
            # Test file integrity based on type
            if [[ "$file" == *.gz ]]; then
                if ! gzip -t "$file" 2>/dev/null; then
                    warn "Corrupted backup detected: $(basename "$file")"
                    corrupt_count=$((corrupt_count + 1))
                fi
            elif [[ "$file" == *.tar ]]; then
                if ! tar -tf "$file" >/dev/null 2>&1; then
                    warn "Corrupted tar backup: $(basename "$file")"
                    corrupt_count=$((corrupt_count + 1))
                fi
            fi
        fi
    done
    
    log "📊 Backup integrity check results:"
    log "   Total backups checked: $backup_count"
    log "   Corrupted backups: $corrupt_count"
    
    if [[ $corrupt_count -eq 0 ]]; then
        log "✅ All backups passed integrity check"
    else
        warn "⚠️ Found $corrupt_count corrupted backup(s)"
    fi
}

# Main function
main() {
    case "$COMMAND" in
        backup)
            create_backup
            ;;
        restore)
            if [[ -z "$RESTORE_FILE" ]]; then
                error "Restore file must be specified"
            fi
            # Add restore logic here
            log "🔄 Restore functionality not yet implemented"
            ;;
        list)
            list_backups
            ;;
        cleanup)
            cleanup_backups
            ;;
        test)
            test_backup
            ;;
        *)
            error "Unknown command: $COMMAND"
            usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@" 