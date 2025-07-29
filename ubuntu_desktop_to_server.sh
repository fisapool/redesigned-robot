#!/bin/bash

# Ubuntu 22.04 Desktop to Server Conversion Script
# Enhanced version with Vast.ai integration
# This script converts Ubuntu Desktop to a minimal server configuration optimized for Vast.ai hosting
# Run this script after installing Ubuntu 22.04 Desktop
# Make executable with: chmod +x ubuntu_desktop_to_server.sh
# Run with: sudo ./ubuntu_desktop_to_server.sh

set -e  # Exit on any error

# Configuration
SCRIPT_VERSION="1.0.0"
LOG_FILE="/var/log/ubuntu_desktop_to_server.log"
BACKUP_DIR="/var/backups/ubuntu-conversion"
CONFIG_FILE="conversion.conf"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Error handling
error_exit() {
    log "ERROR: $1"
    echo -e "${RED}ERROR: $1${NC}" >&2
    exit 1
}

# Success message
success() {
    log "SUCCESS: $1"
    echo -e "${GREEN}SUCCESS: $1${NC}"
}

# Warning message
warning() {
    log "WARNING: $1"
    echo -e "${YELLOW}WARNING: $1${NC}"
}

# Info message
info() {
    log "INFO: $1"
    echo -e "${BLUE}INFO: $1${NC}"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error_exit "This script must be run as root (use sudo)"
    fi
}

# Check Ubuntu version
check_ubuntu_version() {
    if ! command -v lsb_release &> /dev/null; then
        error_exit "lsb_release not found. Please install it first."
    fi
    
    local version=$(lsb_release -rs)
    if [[ "$version" != "22.04" ]]; then
        warning "This script is designed for Ubuntu 22.04. Current version: $version"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi
}

# Create backup
create_backup() {
    info "Creating system backup..."
    mkdir -p "$BACKUP_DIR/$(date +%Y%m%d_%H%M%S)"
    
    # Backup important configuration files
    cp /etc/ssh/sshd_config "$BACKUP_DIR/$(date +%Y%m%d_%H%M%S)/" 2>/dev/null || true
    cp /etc/default/grub "$BACKUP_DIR/$(date +%Y%m%d_%H%M%S)/" 2>/dev/null || true
    cp /etc/apt/sources.list "$BACKUP_DIR/$(date +%Y%m%d_%H%M%S)/" 2>/dev/null || true
    
    success "Backup created in $BACKUP_DIR"
}

# System update
update_system() {
    info "Updating system packages..."
    apt update && apt upgrade -y || error_exit "Failed to update system packages"
    success "System packages updated"
}

# Install essential server packages
install_server_packages() {
    info "Installing essential server packages..."
    
    local packages=(
        openssh-server
        curl
        wget
        vim
        nano
        htop
        screen
        tmux
        git
        build-essential
        software-properties-common
        apt-transport-https
        ca-certificates
        gnupg
        lsb-release
        net-tools
        rsync
        cron
        logrotate
        unattended-upgrades
        ufw
        fail2ban
        chrony
    )
    
    apt install -y "${packages[@]}" || error_exit "Failed to install server packages"
    success "Server packages installed"
}

# Configure SSH
configure_ssh() {
    info "Configuring SSH service..."
    
    # Backup original SSH config
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
    
    # Configure SSH for security
    cat >> /etc/ssh/sshd_config << 'EOF'

# Server security configuration
ClientAliveInterval 60
ClientAliveCountMax 3
PermitRootLogin no
MaxAuthTries 3
LoginGraceTime 60
PasswordAuthentication yes
PubkeyAuthentication yes
X11Forwarding no
AllowTcpForwarding no
PermitTunnel no
DebianBanner no
EOF
    
    # Enable and start SSH
    systemctl enable ssh
    systemctl start ssh
    systemctl restart ssh
    
    success "SSH configured and started"
}

# Remove desktop environment
remove_desktop() {
    info "Removing desktop environment..."
    
    # Stop display manager
    systemctl stop gdm3 2>/dev/null || systemctl stop lightdm 2>/dev/null || true
    systemctl disable gdm3 2>/dev/null || systemctl disable lightdm 2>/dev/null || true
    
    # Remove GNOME desktop and GUI applications
    local gui_packages=(
        ubuntu-desktop
        ubuntu-desktop-minimal
        gnome-shell
        gnome-session
        gdm3
        lightdm
        gnome-control-center
        gnome-terminal
        nautilus
        firefox
        thunderbird
        libreoffice*
        rhythmbox
        shotwell
        totem
        cheese
        evince
        file-roller
        gedit
        gnome-calculator
        gnome-calendar
        gnome-characters
        gnome-clocks
        gnome-contacts
        gnome-font-viewer
        gnome-logs
        gnome-maps
        gnome-photos
        gnome-screenshot
        gnome-system-monitor
        gnome-weather
        simple-scan
        transmission-gtk
        usb-creator-gtk
        yelp
        ubuntu-web-launchers
        ubuntu-report
        update-notifier
        whoopsie
        apport-gtk
        software-properties-gtk
        gnome-software
        snap-store
        ubuntu-advantage-desktop-daemon
    )
    
    for package in "${gui_packages[@]}"; do
        apt remove -y "$package" 2>/dev/null || true
    done
    
    # Remove X11 and graphics
    apt remove -y xorg x11-common plymouth plymouth-theme-ubuntu-logo ubuntu-sounds 2>/dev/null || true
    
    # Remove audio and bluetooth
    apt remove -y alsa-base pulseaudio cups* printer-driver-* system-config-printer-common bluez bluetooth 2>/dev/null || true
    
    success "Desktop environment removed"
}

# Clean snap packages
clean_snap_packages() {
    info "Cleaning snap packages..."
    
    # Remove disabled snaps
    snap list --all | awk '/disabled/{print $1, $3}' | while read snapname revision; do
        snap remove "$snapname" --revision="$revision" 2>/dev/null || true
    done
    
    # Remove GUI snaps
    local gui_snaps=(
        gnome-3-38-2004
        gnome-42-2204
        gtk-common-themes
        snap-store
        firefox
        ubuntu-desktop-installer
    )
    
    for snap in "${gui_snaps[@]}"; do
        snap remove "$snap" 2>/dev/null || true
    done
    
    success "Snap packages cleaned"
}

# Configure system for server
configure_server_system() {
    info "Configuring system for server operation..."
    
    # Set default target to multi-user
    systemctl set-default multi-user.target
    
    # Configure GRUB for server
    sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"/GRUB_CMDLINE_LINUX_DEFAULT=""/' /etc/default/grub
    sed -i 's/#GRUB_TERMINAL=console/GRUB_TERMINAL=console/' /etc/default/grub
    update-grub
    
    # Configure network
    systemctl stop NetworkManager 2>/dev/null || true
    systemctl disable NetworkManager 2>/dev/null || true
    
    # Enable systemd-networkd
    systemctl enable systemd-networkd
    systemctl enable systemd-resolved
    
    # Create network configuration
    cat > /etc/systemd/network/01-dhcp.network << 'EOF'
[Match]
Name=en*

[Network]
DHCP=yes
DNS=8.8.8.8
DNS=8.8.4.4
EOF
    
    success "System configured for server operation"
}

# Configure firewall
configure_firewall() {
    info "Configuring firewall..."
    
    # Reset UFW to defaults
    ufw --force reset
    
    # Configure basic rules
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow ssh
    ufw allow 22/tcp
    
    # Enable firewall
    ufw --force enable
    
    success "Firewall configured"
}

# Configure automatic updates
configure_auto_updates() {
    info "Configuring automatic security updates..."
    
    cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF
    
    cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}";
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};

Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-New-Unused-Dependencies "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF
    
    success "Automatic updates configured"
}

# Clean up system
cleanup_system() {
    info "Cleaning up system..."
    
    # Remove unused packages
    apt autoremove -y --purge
    apt autoclean
    apt clean
    
    # Clean logs
    journalctl --vacuum-time=3d
    
    # Clean package cache
    rm -rf /var/cache/apt/archives/*
    rm -rf /var/lib/apt/lists/*
    
    success "System cleaned up"
}

# Create server utilities
create_utilities() {
    info "Creating server utilities..."
    
    # Create server info script
    cat > /usr/local/bin/server-info << 'EOF'
#!/bin/bash
echo "=== Server Information ==="
echo "Hostname: $(hostname)"
echo "OS: $(lsb_release -d | cut -f2)"
echo "Kernel: $(uname -r)"
echo "Uptime: $(uptime -p)"
echo "IP Address: $(hostname -I | awk '{print $1}')"
echo "Disk Usage:"
df -h / | tail -1
echo "Memory Usage:"
free -h | grep Mem
echo "Load Average: $(uptime | awk -F'load average:' '{print $2}')"
echo "SSH Status: $(systemctl is-active ssh)"
echo "=========================="
EOF
    chmod +x /usr/local/bin/server-info
    
    # Create MOTD
    cat > /etc/update-motd.d/01-server-info << 'EOF'
#!/bin/bash
/usr/local/bin/server-info
EOF
    chmod +x /etc/update-motd.d/01-server-info
    
    # Remove old MOTD files
    rm -f /etc/update-motd.d/10-help-text 2>/dev/null || true
    rm -f /etc/update-motd.d/80-esm 2>/dev/null || true
    rm -f /etc/update-motd.d/95-hwe-eol 2>/dev/null || true
    
    success "Server utilities created"
}

# Main conversion function
main() {
    echo "============================================================"
    echo "Ubuntu 22.04 Desktop to Server Conversion"
    echo "Version: $SCRIPT_VERSION"
    echo "============================================================"
    echo
    
    # Check if running as root
    check_root
    
    # Check Ubuntu version
    check_ubuntu_version
    
    # Confirm user wants to proceed
    echo -e "${YELLOW}WARNING: This will remove the desktop environment and GUI components.${NC}"
    echo -e "${YELLOW}This action cannot be easily undone.${NC}"
    read -p "Do you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Conversion cancelled by user."
        exit 0
    fi
    
    # Create log file
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"
    
    log "Starting Ubuntu Desktop to Server conversion"
    
    # Execute conversion steps
    create_backup
    update_system
    install_server_packages
    configure_ssh
    remove_desktop
    clean_snap_packages
    configure_server_system
    configure_firewall
    configure_auto_updates
    cleanup_system
    create_utilities
    
    echo
    echo "============================================================"
    echo -e "${GREEN}Desktop to Server conversion completed successfully!${NC}"
    echo "============================================================"
    echo
    echo "Changes made:"
    echo "- ✅ Removed desktop environment and GUI applications"
    echo "- ✅ Installed essential server packages"
    echo "- ✅ Configured SSH service"
    echo "- ✅ Set system to boot to console mode"
    echo "- ✅ Configured basic firewall"
    echo "- ✅ Set up automatic security updates"
    echo "- ✅ Configured headless operation"
    echo
    echo "Your system is now configured as a server."
    echo "SSH is enabled and ready for remote connections."
    echo
    echo -e "${YELLOW}IMPORTANT: Reboot required to complete the conversion!${NC}"
    echo "After reboot, you can run the Vast.ai setup script."
    echo
    echo "Log file: $LOG_FILE"
    echo "============================================================"
    
    # Prompt for reboot
    read -p "Reboot now to complete the conversion? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        info "Rebooting in 5 seconds..."
        sleep 5
        reboot
    else
        info "Please reboot when ready: sudo reboot"
    fi
}

# Handle script arguments
case "$1" in
    --help|-h)
        echo "Usage: $0 [OPTIONS]"
        echo
        echo "Convert Ubuntu 22.04 Desktop to Server configuration"
        echo
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --version, -v  Show script version"
        echo
        echo "Examples:"
        echo "  sudo $0"
        exit 0
        ;;
    --version|-v)
        echo "Ubuntu Desktop to Server Conversion Script v$SCRIPT_VERSION"
        exit 0
        ;;
    *)
        main
        ;;
esac
