#!/bin/bash

# Vast.ai Setup Verification Script
# This script verifies that the Vast.ai setup was completed successfully
# Usage: ./verify_vast_setup.sh

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

# Logging function
log() {
    local level=$1
    shift
    local message="$@"
    
    case $level in
        "PASS") echo -e "${GREEN}[PASS]${NC} $message" ;;
        "FAIL") echo -e "${RED}[FAIL]${NC} $message" ;;
        "WARN") echo -e "${YELLOW}[WARN]${NC} $message" ;;
        "INFO") echo -e "${BLUE}[INFO]${NC} $message" ;;
    esac
}

# Check function
check() {
    local description=$1
    local command=$2
    local expected=$3
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    if eval "$command" &>/dev/null; then
        if [[ -n "$expected" ]]; then
            local actual=$(eval "$command")
            if [[ "$actual" == "$expected" ]]; then
                log "PASS" "$description"
                PASSED_CHECKS=$((PASSED_CHECKS + 1))
            else
                log "FAIL" "$description (Expected: $expected, Got: $actual)"
                FAILED_CHECKS=$((FAILED_CHECKS + 1))
            fi
        else
            log "PASS" "$description"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
        fi
    else
        log "FAIL" "$description"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
}

# Check system information
check_system_info() {
    log "INFO" "=== System Information ==="
    
    log "INFO" "OS: $(lsb_release -d | cut -f2)"
    log "INFO" "Kernel: $(uname -r)"
    log "INFO" "Architecture: $(uname -m)"
    
    # Check available disk space
    local disk_space=$(df -h / | awk 'NR==2 {print $4}')
    log "INFO" "Available disk space: $disk_space"
    
    # Check memory
    local memory=$(free -h | awk 'NR==2{printf "%s/%s (%.2f%% used)\n", $3,$2,$3*100/$2 }')
    log "INFO" "Memory usage: $memory"
}

# Check package installations
check_packages() {
    log "INFO" "=== Package Verification ==="
    
    check "build-essential installed" "dpkg -l | grep -q build-essential"
    check "curl installed" "dpkg -l | grep -q curl"
    check "git installed" "dpkg -l | grep -q git"
    check "python3 installed" "dpkg -l | grep -q python3"
    check "openssh-server installed" "dpkg -l | grep -q openssh-server"
}

# Check Docker installation
check_docker() {
    log "INFO" "=== Docker Verification ==="
    
    check "Docker service running" "systemctl is-active docker" "active"
    check "Docker enabled at boot" "systemctl is-enabled docker" "enabled"
    check "Docker version" "docker --version | grep -o 'Docker version [0-9.]*'"
    
    # Test Docker functionality
    if docker run --rm hello-world &>/dev/null; then
        log "PASS" "Docker functionality test"
    else
        log "FAIL" "Docker functionality test"
    fi
    
    # Check Docker user group
    if getent group docker &>/dev/null; then
        log "PASS" "Docker group exists"
    else
        log "FAIL" "Docker group does not exist"
    fi
}

# Check NVIDIA GPU support
check_nvidia() {
    log "INFO" "=== NVIDIA GPU Verification ==="
    
    if ! lspci | grep -i nvidia > /dev/null; then
        log "INFO" "No NVIDIA GPU detected, skipping NVIDIA checks"
        return
    fi
    
    check "NVIDIA GPU detected" "lspci | grep -i nvidia"
    check "NVIDIA driver loaded" "lsmod | grep -q nvidia"
    check "NVIDIA driver version" "nvidia-smi --query-gpu=driver_version --format=csv,noheader,nounits"
    
    # Check NVIDIA container runtime
    if docker run --rm --gpus all nvidia/cuda:11.0-base nvidia-smi &>/dev/null; then
        log "PASS" "NVIDIA container runtime test"
    else
        log "FAIL" "NVIDIA container runtime test"
    fi
}

# Check system configuration
check_system_config() {
    log "INFO" "=== System Configuration Verification ==="
    
    # Check file descriptor limits
    local fd_limit=$(ulimit -n)
    if [[ $fd_limit -ge 65536 ]]; then
        log "PASS" "File descriptor limit ($fd_limit)"
    else
        log "FAIL" "File descriptor limit ($fd_limit < 65536)"
    fi
    
    # Check SSH configuration
    if [[ -f /etc/ssh/sshd_config ]]; then
        check "SSH service running" "systemctl is-active ssh" "active"
        check "SSH enabled at boot" "systemctl is-enabled ssh" "enabled"
    fi
    
    # Check sysctl settings
    local tcp_congestion=$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')
    if [[ "$tcp_congestion" == "bbr" ]]; then
        log "PASS" "TCP congestion control (BBR)"
    else
        log "WARN" "TCP congestion control ($tcp_congestion, expected bbr)"
    fi
}

# Check Vast.ai tools
check_vastai_tools() {
    log "INFO" "=== Vast.ai Tools Verification ==="
    
    # Check Vast.ai CLI
    if command -v vastai &> /dev/null; then
        log "PASS" "Vast.ai CLI installed"
        local version=$(vastai --version 2>/dev/null || echo "unknown")
        log "INFO" "Vast.ai CLI version: $version"
    else
        log "FAIL" "Vast.ai CLI not found"
    fi
    
    # Check working directory
    if [[ -d "/opt/vast" ]]; then
        log "PASS" "Vast.ai working directory exists"
    else
        log "WARN" "Vast.ai working directory not found"
    fi
    
    # Check systemd service
    if [[ -f /etc/systemd/system/vast-daemon.service ]]; then
        log "PASS" "Vast.ai daemon service file exists"
    else
        log "WARN" "Vast.ai daemon service file not found"
    fi
}

# Check network connectivity
check_network() {
    log "INFO" "=== Network Connectivity Verification ==="
    
    check "Internet connectivity" "ping -c 1 google.com"
    check "DNS resolution" "nslookup google.com"
    
    # Check specific Vast.ai endpoints
    local vastai_endpoints=(
        "cloud.vast.ai"
        "api.vast.ai"
    )
    
    for endpoint in "${vastai_endpoints[@]}"; do
        if ping -c 1 "$endpoint" &>/dev/null; then
            log "PASS" "Vast.ai endpoint reachable: $endpoint"
        else
            log "WARN" "Vast.ai endpoint unreachable: $endpoint"
        fi
    done
}

# Generate summary report
generate_report() {
    log "INFO" "=== Verification Summary ==="
    
    echo ""
    echo "Total checks performed: $TOTAL_CHECKS"
    echo -e "Passed: ${GREEN}$PASSED_CHECKS${NC}"
    echo -e "Failed: ${RED}$FAILED_CHECKS${NC}"
    echo -e "Warnings: ${YELLOW}$((TOTAL_CHECKS - PASSED_CHECKS - FAILED_CHECKS))${NC}"
    
    local success_rate=$(( PASSED_CHECKS * 100 / TOTAL_CHECKS ))
    
    if [[ $success_rate -ge 90 ]]; then
        echo -e "${GREEN}✓ Setup verification successful ($success_rate%)${NC}"
    elif [[ $success_rate -ge 75 ]]; then
        echo -e "${YELLOW}⚠ Setup verification mostly successful ($success_rate%)${NC}"
    else
        echo -e "${RED}✗ Setup verification failed ($success_rate%)${NC}"
    fi
    
    echo ""
    
    if [[ $FAILED_CHECKS -gt 0 ]]; then
        echo -e "${RED}Please address the failed checks above.${NC}"
        echo -e "${YELLOW}For support, check the logs at: /var/log/vast_ai_setup_enhanced.log${NC}"
    fi
}

# Main verification function
main() {
    log "INFO" "Starting Vast.ai Setup Verification"
    
    check_system_info
    check_packages
    check_docker
    check_nvidia
    check_system_config
    check_vastai_tools
    check_network
    
    generate_report
    
    if [[ $FAILED_CHECKS -eq 0 ]]; then
        echo -e "${GREEN}✓ All checks passed! Your Vast.ai setup is ready.${NC}"
    else
        echo -e "${YELLOW}⚠ Some issues detected. Please review the report above.${NC}"
        exit 1
    fi
}

# Execute main function
main "$@"
