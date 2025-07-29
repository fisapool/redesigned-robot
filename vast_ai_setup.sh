#!/bin/bash

# Vast.ai Host Setup Script for Ubuntu 22.04 Server
# Run this script after a fresh Ubuntu 22.04 Server installation
# Make executable with: chmod +x vast_ai_setup.sh
# Run with: sudo ./vast_ai_setup.sh

set -e  # Exit on any error

echo "Starting Vast.ai Host Setup for Ubuntu 22.04 Server..."
echo "========================================================"

# Update system packages
echo "Updating system packages..."
apt update && apt upgrade -y && apt dist-upgrade -y

# Install essential packages
echo "Installing essential packages..."
apt install -y \
    build-essential \
    libglvnd-dev \
    pkg-config \
    lm-sensors \
    smartmontools \
    htop \
    curl \
    wget \
    git \
    vim \
    screen \
    tmux \
    unzip \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    openssh-server \
    update-manager-core

# Install Hardware Enablement (HWE) kernel if not already installed
echo "Installing HWE kernel..."
apt install --install-recommends linux-generic-hwe-22.04 -y

# Install Docker
echo "Installing Docker..."
# Remove old Docker versions
apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Start and enable Docker
systemctl start docker
systemctl enable docker

# Add current user to docker group (if not root)
if [ "$SUDO_USER" ]; then
    usermod -aG docker $SUDO_USER
    echo "Added $SUDO_USER to docker group"
fi

# Install NVIDIA drivers and container toolkit
echo "Installing NVIDIA drivers and container toolkit..."

# Detect NVIDIA GPUs
if lspci | grep -i nvidia > /dev/null; then
    echo "NVIDIA GPU detected, installing drivers..."
    
    # Install NVIDIA drivers
    apt install -y nvidia-driver-535 nvidia-dkms-535
    
    # Add NVIDIA container toolkit repository
    distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
    curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list | \
        sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
        tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
    
    # Install NVIDIA container toolkit
    apt update
    apt install -y nvidia-container-toolkit
    
    # Configure Docker to use NVIDIA runtime
    nvidia-ctk runtime configure --runtime=docker
    systemctl restart docker
    
    echo "NVIDIA drivers and container toolkit installed successfully"
else
    echo "No NVIDIA GPU detected, skipping GPU driver installation"
fi

# Configure system settings for optimal performance
echo "Configuring system settings..."

# Increase file descriptor limits
cat >> /etc/security/limits.conf << EOF
* soft nofile 65536
* hard nofile 65536
EOF

# Configure sysctl for better network performance
cat >> /etc/sysctl.conf << EOF
# Network performance tuning
net.core.rmem_max = 268435456
net.core.wmem_max = 268435456
net.ipv4.tcp_rmem = 4096 87380 268435456
net.ipv4.tcp_wmem = 4096 65536 268435456
net.core.netdev_max_backlog = 5000
EOF

# Apply sysctl settings
sysctl -p

# Enable and configure SSH
echo "Configuring SSH..."
systemctl enable ssh
systemctl start ssh

# Configure SSH for better security (optional)
cat >> /etc/ssh/sshd_config << EOF

# Vast.ai optimizations
ClientAliveInterval 60
ClientAliveCountMax 3
MaxSessions 10
EOF

systemctl restart ssh

# Install Python and pip (for Vast.ai CLI)
echo "Installing Python and pip..."
apt install -y python3 python3-pip python3-venv

# Create a directory for Vast.ai
mkdir -p /opt/vast
cd /opt/vast

# Download Vast.ai CLI (optional, for management)
echo "Installing Vast.ai CLI..."
pip3 install vastai

# Create a systemd service file template for Vast.ai daemon
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
ExecStart=/bin/bash -c "echo 'Vast daemon placeholder - configure with actual daemon command'"
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Clean up
echo "Cleaning up..."
apt autoremove -y
apt autoclean

# Display system information
echo "========================================================"
echo "Setup completed! System information:"
echo "========================================================"
echo "OS: $(lsb_release -d | cut -f2)"
echo "Kernel: $(uname -r)"
echo "Docker version: $(docker --version)"

if command -v nvidia-smi &> /dev/null; then
    echo "NVIDIA driver version: $(nvidia-smi --query-gpu=driver_version --format=csv,noheader,nounits | head -1)"
    echo "GPU information:"
    nvidia-smi --query-gpu=name,memory.total --format=csv,noheader
fi

echo "========================================================"
echo "Next steps:"
echo "1. Reboot the system: sudo reboot"
echo "2. After reboot, visit: https://cloud.vast.ai/host/setup"
echo "3. Follow the official Vast.ai hosting setup guide"
echo "4. Download and configure the Vast.ai daemon"
echo "5. Register your machine with Vast.ai"
echo "========================================================"

# Prompt for reboot
read -p "Setup complete! Reboot now? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Rebooting in 5 seconds..."
    sleep 5
    reboot
fi