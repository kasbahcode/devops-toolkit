#!/bin/bash

# 📊 System Monitoring and Health Check Script
# Monitors services, resources, and performs health checks

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
NAMESPACE="default"
CHECK_INTERVAL=30
OUTPUT_FORMAT="table"
ALERT_THRESHOLD_CPU=80
ALERT_THRESHOLD_MEMORY=85
ALERT_THRESHOLD_DISK=90
LOG_FILE="/tmp/monitoring.log"

# Logging functions
log() {
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    echo -e "${GREEN}[$timestamp] $1${NC}" | tee -a "$LOG_FILE"
}

warn() {
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    echo -e "${YELLOW}[$timestamp] WARNING: $1${NC}" | tee -a "$LOG_FILE"
}

error() {
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    echo -e "${RED}[$timestamp] ERROR: $1${NC}" | tee -a "$LOG_FILE"
}

alert() {
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    echo -e "${RED}[$timestamp] 🚨 ALERT: $1${NC}" | tee -a "$LOG_FILE"
    # Add webhook notification here if needed
}

# Usage function
usage() {
    cat << EOF
📊 System Monitoring and Health Check Script

Usage: $0 [OPTIONS] [COMMAND]

Commands:
    health          Run comprehensive health checks
    pods           Monitor Kubernetes pods
    services       Check service status
    resources      Monitor system resources
    logs           Tail application logs
    dashboard      Show monitoring dashboard
    alerts         Check for alerts
    continuous     Run continuous monitoring

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
    $0 pods -n production
    $0 continuous -i 60
    $0 resources --cpu-threshold 70
EOF
}

# Parse command line arguments
COMMAND=""
while [[ $# -gt 0 ]]; do
    case $1 in
        health|pods|services|resources|logs|dashboard|alerts|continuous)
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
            ALERT_THRESHOLD_CPU="$2"
            shift 2
            ;;
        --mem-threshold)
            ALERT_THRESHOLD_MEMORY="$2"
            shift 2
            ;;
        --disk-threshold)
            ALERT_THRESHOLD_DISK="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Default command
if [[ -z "$COMMAND" ]]; then
    COMMAND="health"
fi

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check Docker containers
check_docker_containers() {
    log "🐳 Checking Docker containers..."
    
    if ! command_exists docker; then
        warn "Docker not installed, skipping container checks"
        return
    fi
    
    local containers
    containers=$(docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "")
    
    if [[ -z "$containers" ]]; then
        warn "No Docker containers running"
        return
    fi
    
    echo -e "${CYAN}Docker Containers:${NC}"
    echo "$containers"
    echo
    
    # Check for unhealthy containers
    local unhealthy
    unhealthy=$(docker ps --filter "health=unhealthy" --format "{{.Names}}" 2>/dev/null || echo "")
    
    if [[ -n "$unhealthy" ]]; then
        alert "Unhealthy containers detected: $unhealthy"
    fi
}

# Check Kubernetes pods
check_k8s_pods() {
    log "☸️ Checking Kubernetes pods..."
    
    if ! command_exists kubectl; then
        warn "kubectl not installed, skipping Kubernetes checks"
        return
    fi
    
    if ! kubectl cluster-info >/dev/null 2>&1; then
        warn "Kubernetes cluster not accessible"
        return
    fi
    
    echo -e "${CYAN}Kubernetes Pods in namespace '$NAMESPACE':${NC}"
    kubectl get pods -n "$NAMESPACE" -o wide 2>/dev/null || warn "Could not get pods"
    echo
    
    # Check for failed pods
    local failed_pods
    failed_pods=$(kubectl get pods -n "$NAMESPACE" --field-selector=status.phase=Failed -o name 2>/dev/null || echo "")
    
    if [[ -n "$failed_pods" ]]; then
        alert "Failed pods detected: $failed_pods"
    fi
    
    # Check for pending pods
    local pending_pods
    pending_pods=$(kubectl get pods -n "$NAMESPACE" --field-selector=status.phase=Pending -o name 2>/dev/null || echo "")
    
    if [[ -n "$pending_pods" ]]; then
        warn "Pending pods detected: $pending_pods"
    fi
}

# Check services status
check_services() {
    log "🔍 Checking services status..."
    
    # Check systemd services
    if command_exists systemctl; then
        echo -e "${CYAN}Critical System Services:${NC}"
        local services=("nginx" "docker" "kubelet" "ssh")
        
        for service in "${services[@]}"; do
            if systemctl list-unit-files | grep -q "^$service.service"; then
                local status
                status=$(systemctl is-active "$service" 2>/dev/null || echo "inactive")
                if [[ "$status" == "active" ]]; then
                    echo -e "  ✅ $service: ${GREEN}$status${NC}"
                else
                    echo -e "  ❌ $service: ${RED}$status${NC}"
                    warn "Service $service is not active"
                fi
            fi
        done
        echo
    fi
    
    # Check Kubernetes services
    if command_exists kubectl && kubectl cluster-info >/dev/null 2>&1; then
        echo -e "${CYAN}Kubernetes Services in namespace '$NAMESPACE':${NC}"
        kubectl get services -n "$NAMESPACE" 2>/dev/null || warn "Could not get services"
        echo
    fi
}

# Monitor system resources
check_system_resources() {
    log "💻 Checking system resources..."
    
    echo -e "${CYAN}System Resources:${NC}"
    
    # CPU usage
    if command_exists top; then
        local cpu_usage
        cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//' 2>/dev/null || echo "0")
        echo -e "  CPU Usage: ${cpu_usage}%"
        
        if (( $(echo "$cpu_usage > $ALERT_THRESHOLD_CPU" | bc -l 2>/dev/null || echo 0) )); then
            alert "High CPU usage: ${cpu_usage}%"
        fi
    fi
    
    # Memory usage
    if command_exists free; then
        local mem_info
        mem_info=$(free -m | awk 'NR==2{printf "%.1f", $3*100/$2}' 2>/dev/null || echo "0")
        echo -e "  Memory Usage: ${mem_info}%"
        
        if (( $(echo "$mem_info > $ALERT_THRESHOLD_MEMORY" | bc -l 2>/dev/null || echo 0) )); then
            alert "High memory usage: ${mem_info}%"
        fi
    fi
    
    # Disk usage
    if command_exists df; then
        echo -e "  Disk Usage:"
        df -h / | awk 'NR==2{print "    Root: " $5}' 2>/dev/null || echo "    Root: Unknown"
        
        local disk_usage
        disk_usage=$(df / | awk 'NR==2{print $5}' | sed 's/%//' 2>/dev/null || echo "0")
        
        if (( disk_usage > ALERT_THRESHOLD_DISK )); then
            alert "High disk usage: ${disk_usage}%"
        fi
    fi
    
    # Load average
    if [[ -f /proc/loadavg ]]; then
        local load_avg
        load_avg=$(cat /proc/loadavg | awk '{print $1, $2, $3}' 2>/dev/null || echo "Unknown")
        echo -e "  Load Average: $load_avg"
    fi
    
    echo
}

# Check network connectivity
check_network() {
    log "🌐 Checking network connectivity..."
    
    echo -e "${CYAN}Network Connectivity:${NC}"
    
    # Check internet connectivity
    if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        echo -e "  ✅ Internet: ${GREEN}Connected${NC}"
    else
        echo -e "  ❌ Internet: ${RED}Disconnected${NC}"
        warn "No internet connectivity"
    fi
    
    # Check DNS resolution
    if nslookup google.com >/dev/null 2>&1; then
        echo -e "  ✅ DNS: ${GREEN}Working${NC}"
    else
        echo -e "  ❌ DNS: ${RED}Failed${NC}"
        warn "DNS resolution failed"
    fi
    
    echo
}

# Check application health endpoints
check_health_endpoints() {
    log "🏥 Checking health endpoints..."
    
    local endpoints=(
        "http://localhost:3000/health"
        "http://localhost:8080/health"
        "http://localhost:9090/metrics"
    )
    
    echo -e "${CYAN}Health Endpoints:${NC}"
    
    for endpoint in "${endpoints[@]}"; do
        if curl -sf "$endpoint" >/dev/null 2>&1; then
            echo -e "  ✅ $endpoint: ${GREEN}Healthy${NC}"
        else
            echo -e "  ❌ $endpoint: ${RED}Unhealthy${NC}"
        fi
    done
    
    echo
}

# Display monitoring dashboard
show_dashboard() {
    clear
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                    📊 MONITORING DASHBOARD                    ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    check_system_resources
    check_docker_containers
    check_k8s_pods
    check_services
    check_network
    check_health_endpoints
    
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║ Last Updated: $(date)                              ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
}

# Run comprehensive health check
run_health_check() {
    log "🏥 Running comprehensive health check..."
    
    check_system_resources
    check_docker_containers
    check_k8s_pods
    check_services
    check_network
    check_health_endpoints
    
    log "✅ Health check completed"
}

# Tail application logs
tail_logs() {
    log "📋 Tailing application logs..."
    
    if command_exists kubectl && kubectl cluster-info >/dev/null 2>&1; then
        local pods
        pods=$(kubectl get pods -n "$NAMESPACE" -o name 2>/dev/null | head -5)
        
        if [[ -n "$pods" ]]; then
            echo -e "${CYAN}Following logs for pods in namespace '$NAMESPACE':${NC}"
            kubectl logs -f --tail=100 $pods -n "$NAMESPACE" 2>/dev/null || warn "Could not tail logs"
        else
            warn "No pods found in namespace '$NAMESPACE'"
        fi
    elif command_exists docker; then
        local containers
        containers=$(docker ps --format "{{.Names}}" | head -5)
        
        if [[ -n "$containers" ]]; then
            echo -e "${CYAN}Following Docker container logs:${NC}"
            docker logs -f --tail=100 $containers 2>/dev/null || warn "Could not tail Docker logs"
        else
            warn "No Docker containers running"
        fi
    else
        warn "Neither kubectl nor docker available for log tailing"
    fi
}

# Check for alerts
check_alerts() {
    log "🚨 Checking for alerts..."
    
    local alert_count=0
    
    # Check high resource usage
    if command_exists top; then
        local cpu_usage
        cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//' 2>/dev/null || echo "0")
        if (( $(echo "$cpu_usage > $ALERT_THRESHOLD_CPU" | bc -l 2>/dev/null || echo 0) )); then
            alert "High CPU usage: ${cpu_usage}%"
            ((alert_count++))
        fi
    fi
    
    # Check failed pods
    if command_exists kubectl && kubectl cluster-info >/dev/null 2>&1; then
        local failed_pods
        failed_pods=$(kubectl get pods -n "$NAMESPACE" --field-selector=status.phase=Failed -o name 2>/dev/null | wc -l)
        if (( failed_pods > 0 )); then
            alert "$failed_pods failed pods detected"
            ((alert_count++))
        fi
    fi
    
    if (( alert_count == 0 )); then
        log "✅ No alerts detected"
    else
        warn "$alert_count alerts detected - check logs for details"
    fi
}

# Continuous monitoring
run_continuous_monitoring() {
    log "🔄 Starting continuous monitoring (interval: ${CHECK_INTERVAL}s)"
    log "Press Ctrl+C to stop"
    
    while true; do
        show_dashboard
        check_alerts
        sleep "$CHECK_INTERVAL"
    done
}

# Main function
main() {
    case "$COMMAND" in
        health)
            run_health_check
            ;;
        pods)
            check_k8s_pods
            ;;
        services)
            check_services
            ;;
        resources)
            check_system_resources
            ;;
        logs)
            tail_logs
            ;;
        dashboard)
            show_dashboard
            ;;
        alerts)
            check_alerts
            ;;
        continuous)
            run_continuous_monitoring
            ;;
        *)
            error "Unknown command: $COMMAND"
            usage
            exit 1
            ;;
    esac
}

# Handle Ctrl+C gracefully
trap 'echo -e "\n${YELLOW}Monitoring stopped${NC}"; exit 0' INT

# Run main function
main "$@" 