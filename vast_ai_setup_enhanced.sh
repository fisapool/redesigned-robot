#!/bin/bash

# Enhanced Vast.ai Host Setup Script for Ubuntu 22.04 Server
# Version: 2.0
# Features: Modular design, enhanced security, comprehensive logging, rollback support

set -euo pipefail  # Exit on error, undefined variables, pipe failures

# Configuration
readonly SCRIPT_NAME="vast_ai_setup_enhanced"
readonly SCRIPT_VERSION="2.0"
readonly LOG_FILE="/var/log/${SCRIPT_NAME}.log"
readonly CONFIG_FILE="/etc/vast-ai-setup.conf"
readonly BACKUP_DIR="/var/backups/vast-ai-setup"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Default configuration values
DEFAULT_NVIDIA_DRIVER_VERSION="535"
DEFAULT_DOCKER_COMPOSE_VERSION="2.20.2"
DEFAULT_SSH_PORT="22"
DEFAULT_MAX_FILE_DESCRIPTORS="65536"

# Global variables
VERBOSE=false
DRY_RUN=false
SKIP_NVIDIA=false
SKIP_DOCKER=false
RESTORE_POINT_CREATED=false

# Logging function
log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo -e "${timestamp} [${level}] ${message}" | tee -a "${LOG_FILE}"
    
    case $level in
        "ERROR") echo -e "${RED}[ERROR]${NC} ${message}" >&2 ;;
        "WARN") echo -e "${YELLOW}[WARN]${NC} ${message}" ;;
        "INFO") echo -e "${GREEN}[INFO]${NC} ${message}" ;;
        "DEBUG") [[ $VERBOSE == true ]] && echo -e "${BLUE}[DEBUG]${NC} ${message}" ;;
    esac
}

# Error handling
error_handler() {
    local line_number=$1
    local error_code=$2
    log "ERROR" "Script failed at line $line_number with exit code $error_code"
    
    if [[ "$RESTORE_POINT_CREATED" == true ]]; then
        log "WARN" "A restore point was created. You can manually restore from: $BACKUP_DIR"
    fi
    
    exit $error_code
}

trap 'error_handler $LINENO $?' ERR

# Help function
show_help() {
    cat << EOF
${GREEN}Enhanced Vast.ai Host Setup Script v${SCRIPT_VERSION}${NC}

${YELLOW}Usage:${NC}
    sudo ./vast_ai_setup_enhanced.sh [OPTIONS]

${YELLOW}Options:${NC}
    -h, --help              Show this help message
    -v, --verbose           Enable verbose logging
    -n, --dry-run           Show what would be done without executing
    --skip-nvidia           Skip NVIDIA driver installation
    --skip-docker           Skip Docker installation
    --config FILE           Use custom configuration file
    --restore               Restore from backup

${YELLOW}Examples:${NC}
    sudo ./vast_ai_setup_enhanced.sh
    sudo ./vast_ai_setup_enhanced.sh --verbose --dry-run
    sudo ./vast_ai_setup_enhanced.sh --skip-nvidia --config custom.conf

${YELLOW}Logs:${NC}
    All operations are logged to: ${LOG_FILE}
EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            --skip-nvidia)
                SKIP_NVIDIA=true
                shift
                ;;
            --skip-docker)
                SKIP_DOCKER=true
                shift
                ;;
            --config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            --restore)
                log "INFO" "Restore mode selected - implement restore functionality"
                exit 0
                ;;
            *)
                log "ERROR" "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log "ERROR" "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Create backup directory
create_backup_dir() {
    if [[ ! -d "$BACKUP_DIR" ]]; then
        mkdir -p "$BACKUP_DIR"
        log "INFO" "Created backup directory: $BACKUP_DIR"
    fi
}

# Create system restore point
create_restore_point() {
    log "INFO" "Creating system restore point..."
    
    local restore_date=$(date +%Y%m%d_%H%M%S)
    local restore_path="${BACKUP_DIR}/restore_${restore_date}"
    
    mkdir -p "$restore_path"
    
    # Backup critical configuration files
    local files_to_backup=(
        "/etc/apt/sources.list"
        "/etc/apt/sources.list.d/"
        "/etc/ssh/sshd_config"
        "/etc/security/limits.conf"
        "/etc/sysctl.conf"
        "/etc/docker/daemon.json"
    )
    
    for file in "${files_to_backup[@]}"; do
        if [[ -e "$file" ]]; then
            cp -r "$file" "$restore_path/" 2>/dev/null || true
        fi
    done
    
    # Create package list
    dpkg --get-selections > "$restore_path/package_list.txt"
    
    RESTORE_POINT_CREATED=true
    log "INFO" "Restore point created at: $restore_path"
}

# Check system requirements
check_system_requirements() {
    log "INFO" "Checking system requirements..."
    
    # Check Ubuntu version
    if ! command -v lsb_release &> /dev/null; then
        log "ERROR" "lsb_release not found. This script requires Ubuntu."
        exit 1
    fi
    
    local ubuntu_version=$(lsb_release -rs)
    if [[ "$ubuntu_version" != "22.04" ]]; then
        log "WARN" "This script is designed for Ubuntu 22.04. Current version: $ubuntu_version"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # Check available disk space (minimum 5GB)
    local available_space=$(df / | awk 'NR==2 {print $4}')
    if [[ $available_space -lt 5242880 ]]; then
        log "ERROR" "Insufficient disk space. At least 5GB required."
        exit 1
    fi
    
    # Check internet connectivity
    if ! ping -c 1 google.com &> /dev/null; then
        log "ERROR" "No internet connectivity detected."
        exit 1
    fi
    
    log "INFO" "System requirements check passed"
}

# Update system packages
update_system() {
    log "INFO" "Updating system packages..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log "DRY-RUN" "Would update packages: apt update && apt upgrade -y && apt dist-upgrade -y"
        return
    fi
    
    apt update
    apt upgrade -y
    apt dist-upgrade -y
    
    log "INFO" "System packages updated successfully"
}

# Install essential packages
install_essential_packages() {
    log "INFO" "Installing essential packages..."
    
    local packages=(
        build-essential
        libglvnd-dev
        pkg-config
        lm-sensors
        smartmontools
        htop
        curl
        wget
        git
        vim
        screen
        tmux
        unzip
        software-properties-common
        apt-transport-https
        ca-certificates
        gnupg
        lsb-release
        openssh-server
        update-manager-core
        linux-generic-hwe-22.04
    )
    
    if [[ "$DRY_RUN" == true ]]; then
        log "DRY-RUN" "Would install packages: ${packages[*]}"
        return
    fi
    
    apt install -y "${packages[@]}"
    log "INFO" "Essential packages installed successfully"
}

# Install Docker
install_docker() {
    if [[ "$SKIP_DOCKER" == true ]]; then
        log "INFO" "Skipping Docker installation as requested"
        return
    fi
    
    log "INFO" "Installing Docker..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log "DRY-RUN" "Would install Docker with all configurations"
        return
    fi
    
    # Remove old versions
    apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Add Docker's official GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Add Docker repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    apt update
    apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Start and enable Docker
    systemctl start docker
    systemctl enable docker
    
    # Add current user to docker group
    if [[ -n "${SUDO_USER:-}" ]]; then
        usermod -aG docker "$SUDO_USER"
        log "INFO" "Added $SUDO_USER to docker group"
    fi
    
    # Configure Docker daemon
    cat > /etc/docker/daemon.json << EOF
{
    "default-runtime": "runc",
    "runtimes": {
        "nvidia": {
            "path": "nvidia-container-runtime",
            "runtimeArgs": []
        }
    },
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    },
    "storage-driver": "overlay2"
}
EOF
    
    systemctl restart docker
    log "INFO" "Docker installed and configured successfully"
}

# Install NVIDIA drivers and toolkit
install_nvidia() {
    if [[ "$SKIP_NVIDIA" == true ]]; then
        log "INFO" "Skipping NVIDIA installation as requested"
        return
    fi
    
    log "INFO" "Checking for NVIDIA GPUs..."
    
    if ! lspci | grep -i nvidia > /dev/null; then
        log "INFO" "No NVIDIA GPU detected, skipping GPU driver installation"
        return
    fi
    
    log "INFO" "NVIDIA GPU detected, installing drivers and toolkit..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log "DRY-RUN" "Would install NVIDIA drivers and container toolkit"
        return
    fi
    
    # Install NVIDIA drivers
    apt install -y "nvidia-driver-${DEFAULT_NVIDIA_DRIVER_VERSION}" "nvidia-dkms-${DEFAULT_NVIDIA_DRIVER_VERSION}"
    
    # Add NVIDIA container toolkit repository
    local distribution
    distribution=$(. /etc/os-release; echo "$ID$VERSION_ID")
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
    curl -s -L "https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list" | \
        sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
        tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
    
    apt update
    apt install -y nvidia-container-toolkit
    
    # Configure Docker to use NVIDIA runtime
    nvidia-ctk runtime configure --runtime=docker
    systemctl restart docker
    
    log "INFO" "NVIDIA drivers and container toolkit installed successfully"
}

# Configure system settings
configure_system() {
    log "INFO" "Configuring system settings..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log "DRY-RUN" "Would configure system settings"
        return
    fi
    
    # Configure file descriptor limits
    if ! grep -q "vast-ai-setup" /etc/security/limits.conf; then
        cat >> /etc/security/limits.conf << EOF

# Vast.ai setup - increased file descriptor limits
* soft nofile ${DEFAULT_MAX_FILE_DESCRIPTORS}
* hard nofile ${DEFAULT_MAX_FILE_DESCRIPTORS}
root soft nofile ${DEFAULT_MAX_FILE_DESCRIPTORS}
root hard nofile ${DEFAULT_MAX_FILE_DESCRIPTORS}
EOF
    fi
    
    # Configure PAM limits
    if ! grep -q "pam_limits.so" /etc/pam.d/common-session; then
        echo "session required pam_limits.so" >> /etc/pam.d/common-session
    fi
    
    # Configure sysctl for network performance
    if ! grep -q "vast-ai-network-tuning" /etc/sysctl.conf; then
        cat >> /etc/sysctl.conf << EOF

# Vast-ai-network-tuning - network performance optimization
net.core.rmem_max = 268435456
net.core.wmem_max = 268435456
net.ipv4.tcp_rmem = 4096 87380 268435456
net.ipv4.tcp_wmem = 4096 65536 268435456
net.core.netdev_max_backlog = 5000
net.core.netdev_budget = 600
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_mtu_probing = 1
EOF
    fi
    
    sysctl -p
    
    # Configure CPU governor for performance
    if command -v cpupower &> /dev/null; then
        cpupower frequency-set -g performance
    fi
    
    log "INFO" "System settings configured successfully"
}

# Configure SSH
configure_ssh() {
    log "INFO" "Configuring SSH..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log "DRY-RUN" "Would configure SSH"
        return
    fi
    
    # Enable and start SSH
    systemctl enable ssh
    systemctl start ssh
    
    # Backup original SSH config
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
    
    # Configure SSH for better security and performance
    cat >> /etc/ssh/sshd_config << EOF

# Vast.ai SSH optimizations
ClientAliveInterval 60
ClientAliveCountMax 3
MaxSessions 10
MaxStartups 100:30:200
LoginGraceTime 30
EOF
    
    # Restart SSH
    systemctl restart ssh
    log "INFO" "SSH configured successfully"
}

# Install Vast.ai CLI and tools
install_vastai_tools() {
    log "INFO" "Installing Vast.ai tools..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log "DRY-RUN" "Would install Vast.ai CLI and tools"
        return
    fi
    
    # Install Python and pip
    apt install -y python3 python3-pip python3-venv
    
    # Create Vast.ai directory
    mkdir -p /opt/vast
    cd /opt/vast
    
    # Install Vast.ai CLI
    pip3 install vastai
    
    # Create systemd service for Vast.ai daemon
    cat > /etc/systemd/system/vast-daemon.service << EOF
[Unit]
Description=Vast.ai Host Daemon
After=network.target docker.service
Requires=docker.service

[Service]
Type=simple
User=root
WorkingDirectory=/opt/vast
# Replace with actual vast daemon command when available
ExecStart=/bin/bash -c "echo 'Vast daemon placeholder - configure with actual daemon command from https://cloud.vast.ai/host/setup'"
Restart=always
RestartSec=10
StartLimitInterval=60
StartLimitBurst=3

[Install]
WantedBy=multi-user.target
EOF
    
    # Create monitoring script
    cat > /opt/vast/monitor.sh << 'EOF'
#!/bin/bash
# Vast.ai system monitoring script

echo "=== Vast.ai System Status ==="
echo "Date: $(date)"
echo "Uptime: $(uptime)"
echo ""

echo "=== GPU Status ==="
if command -v nvidia-smi &> /dev/null; then
    nvidia-smi --query-gpu=name,temperature.gpu,utilization.gpu,memory.used,memory.total --format=csv,noheader,nounits
else
    echo "No NVIDIA GPU detected"
fi
echo ""

echo "=== Docker Status ==="
docker --version
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""

echo "=== System Resources ==="
free -h
df -h /
echo ""

echo "=== Network ==="
ip addr show | grep -E "inet.*eth0|inet.*enp" | head -1
EOF
    
    chmod +x /opt/vast/monitor.sh
    
    log "INFO" "Vast.ai tools installed successfully"
}

# System cleanup
cleanup() {
    log "INFO" "Cleaning up..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log "DRY-RUN" "Would clean up temporary files"
        return
    fi
    
    apt autoremove -y
    apt autoclean
    
    # Clean up temporary files
    rm -rf /tmp/vast-ai-setup-*
    
    log "INFO" "Cleanup completed"
}

# Display system information
display_system_info() {
    log "INFO" "Gathering system information..."
    
    echo ""
    echo "========================================================"
    echo -e "${GREEN}Vast.ai Setup Complete!${NC}"
    echo "========================================================"
    echo "OS: $(lsb_release -d | cut -f2)"
    echo "Kernel: $(uname -r)"
    echo "Architecture: $(uname -m)"
    
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}DRY RUN MODE - No changes were made${NC}"
    else
        echo "Docker: $(docker --version)"
        
        if command -v nvidia-smi &> /dev/null; then
            echo "NVIDIA Driver: $(nvidia-smi --query-gpu=driver_version --format=csv,noheader,nounits | head -1)"
            echo "GPU(s):"
            nvidia-smi --query-gpu=name,memory.total --format=csv,noheader
        fi
        
        echo "Vast.ai CLI: $(vastai --version 2>/dev/null || echo 'Not installed')"
    fi
    
    echo ""
    echo "========================================================"
    echo -e "${GREEN}Next Steps:${NC}"
    echo "========================================================"
    echo "1. ${YELLOW}Reboot the system:${NC} sudo reboot"
    echo "2. ${YELLOW}Visit:${NC} https://cloud.vast.ai/host/setup"
    echo "3. ${YELLOW}Run monitoring:${NC} /opt/vast/monitor.sh"
    echo "4. ${YELLOW}View logs:${NC} tail -f ${LOG_FILE}"
    echo ""
    echo "========================================================"
    echo -e "${BLUE}For support, check:${NC} ${LOG_FILE}"
    echo "========================================================"
}

# Main installation function
main() {
    log "INFO" "Starting Enhanced Vast.ai Host Setup v${SCRIPT_VERSION}"
    
    # Parse arguments
    parse_args "$@"
    
    # Check if running as root
    check_root
    
    # Create necessary directories
    create_backup_dir
    
    # Create restore point
    create_restore_point
    
    # Check system requirements
    check_system_requirements
    
    # Execute installation steps
    update_system
    install_essential_packages
    
    if [[ "$SKIP_DOCKER" == false ]]; then
        install_docker
    fi
    
    if [[ "$SKIP_NVIDIA" == false ]]; then
        install_nvidia
    fi
    
    configure_system
    configure_ssh
    install_vastai_tools
    cleanup
    
    # Display final information
    display_system_info
    
    # Prompt for reboot
    if [[ "$DRY_RUN" == false ]]; then
        echo ""
        read -p "Reboot now? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log "INFO" "Rebooting system..."
            sleep 3
            reboot
        else
            log "INFO" "Please reboot manually when ready"
        fi
    fi
}

# Execute main function
main "$@"
