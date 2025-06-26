#!/bin/bash

# 🗄️ Database Migration and Management Script
# Handles database migrations, backups, and maintenance tasks

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
DB_TYPE="postgresql"
DB_HOST="localhost"
DB_PORT="5432"
DB_NAME="devops_toolkit"
DB_USER="postgres"
DB_PASSWORD=""
MIGRATIONS_DIR="./migrations"
BACKUP_DIR="./backups"
ENVIRONMENT="development"

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
🗄️ Database Migration and Management Script

Usage: $0 [COMMAND] [OPTIONS]

Commands:
    create NAME         Create a new migration file
    migrate            Apply pending migrations
    rollback [STEPS]   Rollback migrations (default: 1 step)
    status             Show migration status
    reset              Reset database (WARNING: destructive)
    seed               Run database seeders
    backup             Create database backup
    restore FILE       Restore from backup file
    init               Initialize migration system
    validate           Validate migration files

Options:
    --db-type TYPE     Database type (postgresql, mysql, sqlite) [default: postgresql]
    --host HOST        Database host [default: localhost]
    --port PORT        Database port [default: 5432]
    --database NAME    Database name [default: devops_toolkit]
    --user USER        Database user [default: postgres]
    --password PASS    Database password
    --env ENV          Environment (development, staging, production) [default: development]
    --migrations-dir   Migrations directory [default: ./migrations]
    --backup-dir       Backup directory [default: ./backups]
    -h, --help         Show this help message

Examples:
    $0 create add_users_table
    $0 migrate --env production
    $0 rollback 2
    $0 backup --env production
    $0 restore backup_20231201_120000.sql
EOF
}

# Parse command line arguments
COMMAND=""
MIGRATION_NAME=""
ROLLBACK_STEPS=1
RESTORE_FILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        create|migrate|rollback|status|reset|seed|backup|restore|init|validate)
            COMMAND="$1"
            shift
            ;;
        --db-type)
            DB_TYPE="$2"
            shift 2
            ;;
        --host)
            DB_HOST="$2"
            shift 2
            ;;
        --port)
            DB_PORT="$2"
            shift 2
            ;;
        --database)
            DB_NAME="$2"
            shift 2
            ;;
        --user)
            DB_USER="$2"
            shift 2
            ;;
        --password)
            DB_PASSWORD="$2"
            shift 2
            ;;
        --env)
            ENVIRONMENT="$2"
            shift 2
            ;;
        --migrations-dir)
            MIGRATIONS_DIR="$2"
            shift 2
            ;;
        --backup-dir)
            BACKUP_DIR="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            if [[ "$COMMAND" == "create" && -z "$MIGRATION_NAME" ]]; then
                MIGRATION_NAME="$1"
            elif [[ "$COMMAND" == "rollback" && "$1" =~ ^[0-9]+$ ]]; then
                ROLLBACK_STEPS="$1"
            elif [[ "$COMMAND" == "restore" && -z "$RESTORE_FILE" ]]; then
                RESTORE_FILE="$1"
            else
                error "Unknown option: $1"
            fi
            shift
            ;;
    esac
done

# Load environment variables if .env file exists
if [[ -f ".env" ]]; then
    source .env
fi

# Set database connection string
case "$DB_TYPE" in
    postgresql)
        DB_URL="postgresql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}"
        ;;
    mysql)
        DB_URL="mysql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}"
        ;;
    sqlite)
        DB_URL="sqlite://${DB_NAME}.db"
        ;;
    *)
        error "Unsupported database type: $DB_TYPE"
        ;;
esac

# Create directories
mkdir -p "$MIGRATIONS_DIR" "$BACKUP_DIR"

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check database connection
check_connection() {
    log "🔍 Checking database connection..."
    
    case "$DB_TYPE" in
        postgresql)
            if command_exists psql; then
                PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" >/dev/null 2>&1
            else
                error "psql command not found. Please install PostgreSQL client."
            fi
            ;;
        mysql)
            if command_exists mysql; then
                mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "SELECT 1;" >/dev/null 2>&1
            else
                error "mysql command not found. Please install MySQL client."
            fi
            ;;
        sqlite)
            if command_exists sqlite3; then
                sqlite3 "${DB_NAME}.db" "SELECT 1;" >/dev/null 2>&1
            else
                error "sqlite3 command not found. Please install SQLite."
            fi
            ;;
    esac
    
    log "✅ Database connection successful"
}

# Initialize migration system
init_migrations() {
    log "🚀 Initializing migration system..."
    
    # Create migrations table
    case "$DB_TYPE" in
        postgresql)
            PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" << EOF
CREATE TABLE IF NOT EXISTS schema_migrations (
    version VARCHAR(255) PRIMARY KEY,
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
EOF
            ;;
        mysql)
            mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" << EOF
CREATE TABLE IF NOT EXISTS schema_migrations (
    version VARCHAR(255) PRIMARY KEY,
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
EOF
            ;;
        sqlite)
            sqlite3 "${DB_NAME}.db" << EOF
CREATE TABLE IF NOT EXISTS schema_migrations (
    version TEXT PRIMARY KEY,
    applied_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
EOF
            ;;
    esac
    
    log "✅ Migration system initialized"
}

# Create new migration
create_migration() {
    if [[ -z "$MIGRATION_NAME" ]]; then
        error "Migration name is required"
    fi
    
    local timestamp=$(date +"%Y%m%d%H%M%S")
    local migration_file="${MIGRATIONS_DIR}/${timestamp}_${MIGRATION_NAME}.sql"
    
    log "📝 Creating migration: $migration_file"
    
    cat > "$migration_file" << EOF
-- Migration: $MIGRATION_NAME
-- Created: $(date)

-- +migrate Up
-- Add your migration SQL here


-- +migrate Down
-- Add your rollback SQL here

EOF
    
    log "✅ Migration file created: $migration_file"
    info "Edit the file to add your migration SQL"
}

# Get pending migrations
get_pending_migrations() {
    local applied_migrations
    
    case "$DB_TYPE" in
        postgresql)
            applied_migrations=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT version FROM schema_migrations ORDER BY version;" 2>/dev/null | tr -d ' ')
            ;;
        mysql)
            applied_migrations=$(mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -s -e "SELECT version FROM schema_migrations ORDER BY version;" 2>/dev/null)
            ;;
        sqlite)
            applied_migrations=$(sqlite3 "${DB_NAME}.db" "SELECT version FROM schema_migrations ORDER BY version;" 2>/dev/null)
            ;;
    esac
    
    # Get all migration files
    local all_migrations
    all_migrations=$(find "$MIGRATIONS_DIR" -name "*.sql" -type f | sort | xargs -I {} basename {} .sql)
    
    # Find pending migrations
    local pending_migrations=""
    for migration in $all_migrations; do
        if ! echo "$applied_migrations" | grep -q "^$migration$"; then
            pending_migrations="$pending_migrations $migration"
        fi
    done
    
    echo "$pending_migrations"
}

# Apply migrations
apply_migrations() {
    log "🔄 Applying pending migrations..."
    
    local pending_migrations
    pending_migrations=$(get_pending_migrations)
    
    if [[ -z "$pending_migrations" ]]; then
        log "✅ No pending migrations"
        return
    fi
    
    for migration in $pending_migrations; do
        local migration_file="${MIGRATIONS_DIR}/${migration}.sql"
        
        if [[ ! -f "$migration_file" ]]; then
            warn "Migration file not found: $migration_file"
            continue
        fi
        
        log "Applying migration: $migration"
        
        # Extract the "Up" part of the migration
        local up_sql
        up_sql=$(sed -n '/-- +migrate Up/,/-- +migrate Down/p' "$migration_file" | sed '1d;$d')
        
        if [[ -n "$up_sql" ]]; then
            case "$DB_TYPE" in
                postgresql)
                    echo "$up_sql" | PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME"
                    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "INSERT INTO schema_migrations (version) VALUES ('$migration');"
                    ;;
                mysql)
                    echo "$up_sql" | mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME"
                    mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "INSERT INTO schema_migrations (version) VALUES ('$migration');"
                    ;;
                sqlite)
                    echo "$up_sql" | sqlite3 "${DB_NAME}.db"
                    sqlite3 "${DB_NAME}.db" "INSERT INTO schema_migrations (version) VALUES ('$migration');"
                    ;;
            esac
            
            log "✅ Applied migration: $migration"
        else
            warn "No migration SQL found in: $migration_file"
        fi
    done
    
    log "✅ All migrations applied successfully"
}

# Rollback migrations
rollback_migrations() {
    log "⏪ Rolling back $ROLLBACK_STEPS migration(s)..."
    
    # Get applied migrations in reverse order
    local applied_migrations
    case "$DB_TYPE" in
        postgresql)
            applied_migrations=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT version FROM schema_migrations ORDER BY version DESC LIMIT $ROLLBACK_STEPS;" 2>/dev/null | tr -d ' ')
            ;;
        mysql)
            applied_migrations=$(mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -s -e "SELECT version FROM schema_migrations ORDER BY version DESC LIMIT $ROLLBACK_STEPS;" 2>/dev/null)
            ;;
        sqlite)
            applied_migrations=$(sqlite3 "${DB_NAME}.db" "SELECT version FROM schema_migrations ORDER BY version DESC LIMIT $ROLLBACK_STEPS;" 2>/dev/null)
            ;;
    esac
    
    if [[ -z "$applied_migrations" ]]; then
        log "✅ No migrations to rollback"
        return
    fi
    
    for migration in $applied_migrations; do
        local migration_file="${MIGRATIONS_DIR}/${migration}.sql"
        
        if [[ ! -f "$migration_file" ]]; then
            warn "Migration file not found: $migration_file"
            continue
        fi
        
        log "Rolling back migration: $migration"
        
        # Extract the "Down" part of the migration
        local down_sql
        down_sql=$(sed -n '/-- +migrate Down/,$p' "$migration_file" | sed '1d')
        
        if [[ -n "$down_sql" ]]; then
            case "$DB_TYPE" in
                postgresql)
                    echo "$down_sql" | PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME"
                    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "DELETE FROM schema_migrations WHERE version = '$migration';"
                    ;;
                mysql)
                    echo "$down_sql" | mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME"
                    mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "DELETE FROM schema_migrations WHERE version = '$migration';"
                    ;;
                sqlite)
                    echo "$down_sql" | sqlite3 "${DB_NAME}.db"
                    sqlite3 "${DB_NAME}.db" "DELETE FROM schema_migrations WHERE version = '$migration';"
                    ;;
            esac
            
            log "✅ Rolled back migration: $migration"
        else
            warn "No rollback SQL found in: $migration_file"
        fi
    done
    
    log "✅ Rollback completed successfully"
}

# Show migration status
show_status() {
    log "📊 Migration status:"
    
    local applied_migrations
    case "$DB_TYPE" in
        postgresql)
            applied_migrations=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT version FROM schema_migrations ORDER BY version;" 2>/dev/null | tr -d ' ')
            ;;
        mysql)
            applied_migrations=$(mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -s -e "SELECT version FROM schema_migrations ORDER BY version;" 2>/dev/null)
            ;;
        sqlite)
            applied_migrations=$(sqlite3 "${DB_NAME}.db" "SELECT version FROM schema_migrations ORDER BY version;" 2>/dev/null)
            ;;
    esac
    
    # Get all migration files
    local all_migrations
    all_migrations=$(find "$MIGRATIONS_DIR" -name "*.sql" -type f | sort | xargs -I {} basename {} .sql)
    
    echo "Applied migrations:"
    if [[ -n "$applied_migrations" ]]; then
        echo "$applied_migrations" | while read -r migration; do
            echo "  ✅ $migration"
        done
    else
        echo "  (none)"
    fi
    
    echo ""
    echo "Pending migrations:"
    local has_pending=false
    for migration in $all_migrations; do
        if ! echo "$applied_migrations" | grep -q "^$migration$"; then
            echo "  ⏳ $migration"
            has_pending=true
        fi
    done
    
    if [[ "$has_pending" == "false" ]]; then
        echo "  (none)"
    fi
}

# Create database backup
create_backup() {
    log "💾 Creating database backup..."
    
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_file="${BACKUP_DIR}/backup_${timestamp}.sql"
    
    case "$DB_TYPE" in
        postgresql)
            PGPASSWORD="$DB_PASSWORD" pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" "$DB_NAME" > "$backup_file"
            ;;
        mysql)
            mysqldump -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" > "$backup_file"
            ;;
        sqlite)
            sqlite3 "${DB_NAME}.db" ".dump" > "$backup_file"
            ;;
    esac
    
    # Compress backup
    gzip "$backup_file"
    backup_file="${backup_file}.gz"
    
    log "✅ Backup created: $backup_file"
}

# Restore from backup
restore_backup() {
    if [[ -z "$RESTORE_FILE" ]]; then
        error "Backup file is required"
    fi
    
    if [[ ! -f "$RESTORE_FILE" ]]; then
        error "Backup file not found: $RESTORE_FILE"
    fi
    
    log "🔄 Restoring from backup: $RESTORE_FILE"
    
    # Decompress if needed
    local temp_file="$RESTORE_FILE"
    if [[ "$RESTORE_FILE" == *.gz ]]; then
        temp_file="/tmp/restore_$(date +%s).sql"
        gunzip -c "$RESTORE_FILE" > "$temp_file"
    fi
    
    case "$DB_TYPE" in
        postgresql)
            PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" < "$temp_file"
            ;;
        mysql)
            mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" < "$temp_file"
            ;;
        sqlite)
            sqlite3 "${DB_NAME}.db" < "$temp_file"
            ;;
    esac
    
    # Clean up temp file
    if [[ "$temp_file" != "$RESTORE_FILE" ]]; then
        rm "$temp_file"
    fi
    
    log "✅ Database restored successfully"
}

# Main function
main() {
    if [[ -z "$COMMAND" ]]; then
        usage
        exit 1
    fi
    
    # Check database connection for most commands
    if [[ "$COMMAND" != "create" && "$COMMAND" != "init" ]]; then
        check_connection
    fi
    
    case "$COMMAND" in
        init)
            init_migrations
            ;;
        create)
            create_migration
            ;;
        migrate)
            apply_migrations
            ;;
        rollback)
            rollback_migrations
            ;;
        status)
            show_status
            ;;
        backup)
            create_backup
            ;;
        restore)
            restore_backup
            ;;
        *)
            error "Unknown command: $COMMAND"
            ;;
    esac
}

# Run main function
main "$@" 