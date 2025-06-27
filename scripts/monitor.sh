#!/bin/bash

# 📊 Monitoring and Health Check Script
# Provides comprehensive monitoring of your applications and infrastructure

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default configuration
NAMESPACE="default"
CHECK_INTERVAL=30
OUTPUT_FORMAT="table"
CPU_THRESHOLD=80
MEM_THRESHOLD=85
DISK_THRESHOLD=90

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
📊 Monitoring and Health Check Script

Usage: $0 [COMMAND] [OPTIONS]

Commands:
    health              Check system health
    metrics             Display current metrics
    alerts              Show active alerts
    services            Check service status
    logs                Display recent logs
    performance         Performance analysis

Options:
    -n, --namespace NS     Kubernetes namespace [default: default]
    -i, --interval SEC     Check interval in seconds [default: 30]
    -f, --format FORMAT    Output format (table, json, yaml) [default: table]
    --cpu-threshold NUM    CPU alert threshold percentage [default: 80]
    --mem-threshold NUM    Memory alert threshold percentage [default: 85]
    --disk-threshold NUM   Disk alert threshold percentage [default: 90]
    -h, --help            Show this help message

Examples:
    $0 health
    $0 metrics --format json
    $0 services --namespace production
    $0 performance --cpu-threshold 90
EOF
}

# Parse command line arguments
COMMAND=""
while [[ $# -gt 0 ]]; do
    case $1 in
        health|metrics|alerts|services|logs|performance)
            COMMAND="$1"
            shift
            ;;
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -i|--interval)
            CHECK_INTERVAL="$2"
            shift 2
            ;;
        -f|--format)
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        --cpu-threshold)
            CPU_THRESHOLD="$2"
            shift 2
            ;;
        --mem-threshold)
            MEM_THRESHOLD="$2"
            shift 2
            ;;
        --disk-threshold)
            DISK_THRESHOLD="$2"
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

# Default command
if [[ -z "$COMMAND" ]]; then
    COMMAND="health"
fi

# Check if Docker is running
check_docker() {
    if ! docker info >/dev/null 2>&1; then
        error "Docker is not running. Please start Docker and try again."
    fi
}

# Check system health
check_health() {
    log "🏥 Performing comprehensive health check..."
    
    local issues=0
    
    # Docker health
    if docker info >/dev/null 2>&1; then
        log "✅ Docker is running"
    else
        warn "❌ Docker is not running"
        ((issues++))
    fi
    
    # Docker containers
    if command -v docker-compose >/dev/null 2>&1; then
        local running_containers=$(docker-compose ps -q 2>/dev/null | wc -l)
        if [[ $running_containers -gt 0 ]]; then
            log "✅ Docker Compose services: $running_containers running"
        else
            warn "❌ No Docker Compose services running"
            ((issues++))
        fi
    fi
    
    # Kubernetes health (if available)
    if command -v kubectl >/dev/null 2>&1 && kubectl cluster-info >/dev/null 2>&1; then
        local ready_nodes=$(kubectl get nodes --no-headers 2>/dev/null | grep " Ready" | wc -l)
        log "✅ Kubernetes cluster: $ready_nodes nodes ready"
        
        local running_pods=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | grep "Running" | wc -l)
        log "✅ Kubernetes pods: $running_pods running in namespace $NAMESPACE"
    else
        info "ℹ️ Kubernetes not available or not configured"
    fi
    
    # Disk space
    local disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    if [[ $disk_usage -lt $DISK_THRESHOLD ]]; then
        log "✅ Disk usage: ${disk_usage}%"
    else
        warn "❌ High disk usage: ${disk_usage}% (threshold: ${DISK_THRESHOLD}%)"
        ((issues++))
    fi
    
    # Memory usage
    if command -v free >/dev/null 2>&1; then
        local mem_usage=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}')
        if [[ $mem_usage -lt $MEM_THRESHOLD ]]; then
            log "✅ Memory usage: ${mem_usage}%"
        else
            warn "❌ High memory usage: ${mem_usage}% (threshold: ${MEM_THRESHOLD}%)"
            ((issues++))
        fi
    else
        info "ℹ️ Memory monitoring not available on this system"
    fi
    
    # Summary
    if [[ $issues -eq 0 ]]; then
        log "🎉 All health checks passed!"
        return 0
    else
        warn "⚠️ Found $issues issue(s) that need attention"
        return 1
    fi
}

# Display metrics
show_metrics() {
    log "📊 Current system metrics..."
    
    # System metrics
    if command -v top >/dev/null 2>&1; then
        info "CPU Usage:"
        top -l 1 | grep "CPU usage" 2>/dev/null || echo "CPU info not available"
    fi
    
    if command -v free >/dev/null 2>&1; then
        info "Memory Usage:"
        free -h
    fi
    
    info "Disk Usage:"
    df -h / | tail -1
    
    # Docker metrics
    if docker info >/dev/null 2>&1; then
        info "Docker Containers:"
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    fi
    
    # Kubernetes metrics (if available)
    if command -v kubectl >/dev/null 2>&1 && kubectl cluster-info >/dev/null 2>&1; then
        info "Kubernetes Pods:"
        kubectl top pods -n "$NAMESPACE" 2>/dev/null || echo "Metrics not available (metrics-server not installed)"
    fi
}

# Show service status
show_services() {
    log "🔧 Checking service status..."
    
    # Docker services
    if command -v docker-compose >/dev/null 2>&1; then
        info "Docker Compose Services:"
        docker-compose ps 2>/dev/null || echo "No docker-compose.yml found"
    fi
    
    # Kubernetes services
    if command -v kubectl >/dev/null 2>&1 && kubectl cluster-info >/dev/null 2>&1; then
        info "Kubernetes Services:"
        kubectl get services -n "$NAMESPACE" 2>/dev/null || echo "Cannot access Kubernetes cluster"
    fi
    
    # Check common service ports
    info "Port Status:"
    local ports=(3000 9090 9093 5601)
    for port in "${ports[@]}"; do
        if lsof -i:$port >/dev/null 2>&1; then
            log "✅ Port $port: In use"
        else
            warn "❌ Port $port: Not in use"
        fi
    done
}

# Show recent logs
show_logs() {
    log "📄 Recent logs..."
    
    # Docker logs
    if command -v docker-compose >/dev/null 2>&1; then
        info "Docker Compose Logs (last 50 lines):"
        docker-compose logs --tail=50 2>/dev/null || echo "No docker-compose services running"
    fi
    
    # Kubernetes logs
    if command -v kubectl >/dev/null 2>&1 && kubectl cluster-info >/dev/null 2>&1; then
        info "Kubernetes Logs (last 50 lines):"
        kubectl logs --tail=50 -l app --all-containers=true -n "$NAMESPACE" 2>/dev/null || echo "No pods with app label found"
    fi
}

# Performance analysis
performance_analysis() {
    log "⚡ Performance analysis..."
    
    # Load average
    if [[ -f /proc/loadavg ]]; then
        local load=$(cat /proc/loadavg | cut -d' ' -f1-3)
        info "Load Average: $load"
    fi
    
    # Top processes
    info "Top CPU processes:"
    if command -v ps >/dev/null 2>&1; then
        ps aux --sort=-%cpu | head -6
    fi
    
    # Network connections
    info "Active network connections:"
    if command -v ss >/dev/null 2>&1; then
        ss -tuln | grep LISTEN | head -10
    elif command -v netstat >/dev/null 2>&1; then
        netstat -tuln | grep LISTEN | head -10
    fi
    
    # Docker stats (if running)
    if docker info >/dev/null 2>&1; then
        local running_containers=$(docker ps -q)
        if [[ -n "$running_containers" ]]; then
            info "Docker container stats:"
            docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"
        fi
    fi
}

# Check Prometheus alerts via API
check_prometheus_alerts() {
    local prometheus_url="http://localhost:9090"
    local alerts_endpoint="${prometheus_url}/api/v1/alerts"
    
    if curl -s "$alerts_endpoint" >/dev/null 2>&1; then
        local active_alerts=$(curl -s "$alerts_endpoint" | jq -r '.data[] | select(.state=="firing") | .labels.alertname' 2>/dev/null | wc -l)
        if [[ $active_alerts -gt 0 ]]; then
            warn "🚨 Found $active_alerts active alert(s)"
            curl -s "$alerts_endpoint" | jq -r '.data[] | select(.state=="firing") | "- \(.labels.alertname): \(.annotations.summary)"' 2>/dev/null || echo "Alert details unavailable"
        else
            log "✅ No active alerts"
        fi
    else
        info "ℹ️ Prometheus not available for alert checking"
    fi
}
show_alerts() {
    log "🚨 Checking for active alerts..."
    
    # Check if Prometheus is available
    if curl -s http://localhost:9090/api/v1/alerts >/dev/null 2>&1; then
        info "Prometheus alerts:"
        curl -s http://localhost:9090/api/v1/alerts | jq '.data.alerts[] | select(.state=="firing") | {alertname: .labels.alertname, severity: .labels.severity}' 2>/dev/null || echo "No active alerts or jq not installed"
    else
        warn "Prometheus not available at http://localhost:9090"
    fi
    
    # Basic system alerts
    info "System alerts:"
    
    # Check disk space
    local disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    if [[ $disk_usage -gt $DISK_THRESHOLD ]]; then
        warn "🔴 HIGH DISK USAGE: ${disk_usage}%"
    fi
    
    # Check memory
    if command -v free >/dev/null 2>&1; then
        local mem_usage=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}')
        if [[ $mem_usage -gt $MEM_THRESHOLD ]]; then
            warn "🔴 HIGH MEMORY USAGE: ${mem_usage}%"
        fi
    fi
    
    # Check load average
    if [[ -f /proc/loadavg ]]; then
        local load=$(cat /proc/loadavg | cut -d' ' -f1)
        local cores=$(nproc 2>/dev/null || echo 1)
        if (( $(echo "$load > $cores * 2" | bc -l 2>/dev/null || echo 0) )); then
            warn "🔴 HIGH LOAD AVERAGE: $load (cores: $cores)"
        fi
    fi
}

# Main function
main() {
    case "$COMMAND" in
        health)
            check_health
            ;;
        metrics)
            show_metrics
            ;;
        alerts)
            show_alerts
            ;;
        services)
            show_services
            ;;
        logs)
            show_logs
            ;;
        performance)
            performance_analysis
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