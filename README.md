# Enhanced Vast.ai Host Setup

This repository contains an enhanced version of the Vast.ai host setup script with improved security, error handling, and modular design.

## Files Overview

- **`vast_ai_setup_enhanced.sh`** - Enhanced setup script with comprehensive features
- **`vast-ai-setup.conf`** - Configuration file for customizing the setup
- **`verify_vast_setup.sh`** - Verification script to test the installation
- **`vast_ai_setup.sh`** - Original script for reference

## Features

### Enhanced Script Features
- **Modular Design**: Organized into functions for better maintainability
- **Comprehensive Logging**: All operations logged to `/var/log/vast_ai_setup_enhanced.log`
- **Error Handling**: Robust error handling with rollback capabilities
- **Dry Run Mode**: Test changes without executing them
- **Configuration Support**: Customizable via configuration file
- **Backup & Restore**: Automatic backup creation before changes
- **Security Enhancements**: Improved SSH and Docker security
- **Progress Indicators**: Clear feedback during installation
- **Verification Tools**: Built-in verification script

### Security Improvements
- Enhanced SSH configuration
- Docker security hardening
- System limits configuration
- Firewall support (configurable)
- Fail2ban integration (optional)

### Performance Optimizations
- TCP BBR congestion control
- Optimized network buffers
- CPU governor settings
- File descriptor limits
- Docker performance tuning

## Quick Start

### 1. Basic Usage
```bash
# Make the script executable
chmod +x vast_ai_setup_enhanced.sh

# Run with default settings
sudo ./vast_ai_setup_enhanced.sh

# Run with verbose logging
sudo ./vast_ai_setup_enhanced.sh --verbose
```

### 2. Advanced Usage
```bash
# Dry run to see what would be done
sudo ./vast_ai_setup_enhanced.sh --dry-run

# Skip NVIDIA installation
sudo ./vast_ai_setup_enhanced.sh --skip-nvidia

# Use custom configuration
sudo ./vast_ai_setup_enhanced.sh --config custom.conf

# Show help
sudo ./vast_ai_setup_enhanced.sh --help
```

### 3. Verification
```bash
# Verify the installation
chmod +x verify_vast_setup.sh
./verify_vast_setup.sh
```

## Configuration

### Custom Configuration File
Create a custom configuration file based on `vast-ai-setup.conf`:

```bash
cp vast-ai-setup.conf my-config.conf
# Edit my-config.conf with your preferences
sudo ./vast_ai_setup_enhanced.sh --config my-config.conf
```

### Key Configuration Options
- **NVIDIA_DRIVER_VERSION**: GPU driver version (default: 535)
- **MAX_FILE_DESCRIPTORS**: System file descriptor limit (default: 65536)
- **SSH_PORT**: SSH port configuration (default: 22)
- **ENABLE_FIREWALL**: Enable firewall (default: true)
- **ENABLE_FAIL2BAN**: Enable fail2ban (default: false)

## Installation Process

### 1. Pre-Installation
- System requirements check
- Internet connectivity verification
- Disk space validation
- Backup creation

### 2. Installation Steps
1. **System Update**: Update all packages
2. **Essential Packages**: Install build tools and utilities
3. **Docker Installation**: Latest Docker CE with security
4. **NVIDIA Support**: GPU drivers and container toolkit
5. **System Configuration**: Performance optimizations
6. **SSH Setup**: Secure SSH configuration
7. **Vast.ai Tools**: CLI and monitoring tools
8. **Verification**: System health checks

### 3. Post-Installation
- System reboot (recommended)
- Verification script execution
- Vast.ai daemon configuration

## Verification

The verification script checks:
- ✅ System packages installation
- ✅ Docker service status
- ✅ NVIDIA GPU support (if applicable)
- ✅ System configuration
- ✅ Network connectivity
- ✅ Vast.ai tools availability

## Troubleshooting

### Common Issues

#### 1. Permission Errors
```bash
# Ensure script is run as root
sudo ./vast_ai_setup_enhanced.sh
```

#### 2. NVIDIA Driver Issues
```bash
# Skip NVIDIA installation
sudo ./vast_ai_setup_enhanced.sh --skip-nvidia
```

#### 3. Docker Issues
```bash
# Skip Docker installation
sudo ./vast_ai_setup_enhanced.sh --skip-docker
```

#### 4. Network Issues
```bash
# Check logs
tail -f /var/log/vast_ai_setup_enhanced.log
```

### Log Files
- **Setup Log**: `/var/log/vast_ai_setup_enhanced.log`
- **System Log**: `/var/log/syslog`
- **Docker Log**: `/var/log/docker.log`

### Restore from Backup
If issues occur, restore from the automatically created backup:
```bash
# Backup location
ls -la /var/backups/vast-ai-setup/

# Manual restore (example)
sudo cp /var/backups/vast-ai-setup/restore_*/sshd_config /etc/ssh/
```

## Monitoring

### Built-in Monitoring
```bash
# System status
/opt/vast/monitor.sh

# Real-time monitoring
watch -n 5 /opt/vast/monitor.sh
```

### Log Monitoring
```bash
# Setup logs
tail -f /var/log/vast_ai_setup_enhanced.log

# Docker logs
journalctl -u docker -f

# System logs
journalctl -f
```

## Security Checklist

- [ ] SSH key-based authentication configured
- [ ] Firewall enabled (if configured)
- [ ] Docker daemon secured
- [ ] System updates applied
- [ ] Monitoring enabled
- [ ] Backup verification completed

## Performance Tuning

### Network Optimization
- TCP BBR congestion control
- Optimized buffer sizes
- Network queue management

### System Optimization
- File descriptor limits
- CPU governor settings
- Memory management
- Docker performance tuning

## Support

### Getting Help
1. Check the logs: `/var/log/vast_ai_setup_enhanced.log`
2. Run verification: `./verify_vast_setup.sh`
3. Review configuration: `vast-ai-setup.conf`
4. Check system resources: `/opt/vast/monitor.sh`

### Vast.ai Resources
- **Official Setup**: https://cloud.vast.ai/host/setup/
- **Documentation**: https://vast.ai/docs/
- **Support**: https://vast.ai/support/

## Contributing

To contribute improvements:
1. Test changes in a clean Ubuntu 22.04 environment
2. Update documentation
3. Run verification script
4. Submit pull request with detailed description

## License

This enhanced script is provided as-is for educational and operational purposes. Please review and test thoroughly before use in production environments.
