# 📥 Complete Installation Guide
### Step-by-Step Setup for All Operating Systems

This guide provides comprehensive installation instructions for the DevOps Toolkit on macOS, Linux, and Windows. Follow the instructions specific to your operating system.

---

## 📋 Table of Contents

1. [Quick Installation](#quick-installation)
2. [System Requirements](#system-requirements)
3. [macOS Installation](#macos-installation)
4. [Linux Installation](#linux-installation)
5. [Windows Installation](#windows-installation)
6. [Docker Desktop Setup](#docker-desktop-setup)
7. [Verification Steps](#verification-steps)
8. [Troubleshooting](#troubleshooting)
9. [Advanced Configuration](#advanced-configuration)

---

## ⚡ Quick Installation

**For users who want to get started immediately:**

```bash
# 1. Clone the repository
git clone https://github.com/kasbahcode/devops-toolkit.git
cd devops-toolkit

# 2. Run the magic setup script
chmod +x scripts/setup.sh
./scripts/setup.sh

# 3. Verify installation
./scripts/monitor.sh health
```

**That's it!** The setup script automatically detects your OS and installs all dependencies.

---

## 💻 System Requirements

### Minimum Requirements
- **CPU**: 2 cores (4 cores recommended)
- **RAM**: 4GB (8GB recommended)
- **Storage**: 10GB free space (20GB recommended)
- **Network**: Stable internet connection

### Operating System Support
- ✅ **macOS**: 10.15+ (Catalina or newer)
- ✅ **Linux**: Ubuntu 18.04+, CentOS 7+, Debian 10+
- ✅ **Windows**: 10/11 with WSL2

### Software Dependencies
*Automatically installed by setup script:*
- Git
- Docker Desktop / Docker Engine
- Node.js 18+
- kubectl
- Terraform
- Ansible
- Python 3.8+

---

## 🍎 macOS Installation

### Prerequisites Check
```bash
# Check macOS version
sw_vers -productVersion

# Should show 10.15 or higher
```

### Step 1: Install Homebrew (Package Manager)
```bash
# Install Homebrew if you don't have it
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Add Homebrew to PATH
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zshrc
source ~/.zshrc
```

### Step 2: Install Git
```bash
# Install Git via Homebrew
brew install git

# Verify installation
git --version
```

### Step 3: Clone and Setup DevOps Toolkit
```bash
# Clone the repository
git clone https://github.com/kasbahcode/devops-toolkit.git
cd devops-toolkit

# Make scripts executable
chmod +x scripts/*.sh

# Run setup (installs Docker, Node.js, kubectl, etc.)
./scripts/setup.sh
```

### Step 4: Install Docker Desktop
```bash
# The setup script will guide you through Docker Desktop installation
# Or install manually:
brew install --cask docker

# Start Docker Desktop from Applications folder
open -a Docker
```

### Step 5: Verification
```bash
# Verify all components
./scripts/monitor.sh health

# Check Docker
docker --version
docker run hello-world

# Check Node.js
node --version
npm --version
```

### macOS-Specific Notes
- **Rosetta 2**: If using Apple Silicon (M1/M2), some Docker images may require Rosetta 2
- **Firewall**: You may need to allow Docker through macOS firewall
- **Xcode Tools**: Git installation might prompt for Xcode command line tools

---

## 🐧 Linux Installation

### Ubuntu/Debian Installation

#### Step 1: Update System
```bash
# Update package index
sudo apt update && sudo apt upgrade -y

# Install essential packages
sudo apt install -y curl wget gnupg lsb-release software-properties-common
```

#### Step 2: Install Git
```bash
# Install Git
sudo apt install -y git

# Verify installation
git --version
```

#### Step 3: Clone DevOps Toolkit
```bash
# Clone repository
git clone https://github.com/kasbahcode/devops-toolkit.git
cd devops-toolkit

# Make scripts executable
chmod +x scripts/*.sh
```

#### Step 4: Run Setup Script
```bash
# The setup script handles everything else
./scripts/setup.sh

# This installs:
# - Docker Engine
# - Node.js
# - kubectl
# - Terraform
# - Ansible
# - Python dependencies
```

#### Step 5: Configure Docker (Ubuntu/Debian)
```bash
# Add your user to docker group (already done by setup script)
sudo usermod -aG docker $USER

# Log out and log back in, or run:
newgrp docker

# Test Docker
docker run hello-world
```

### CentOS/RHEL Installation

#### Step 1: Update System
```bash
# Update system
sudo yum update -y

# Install essential packages
sudo yum install -y curl wget git
```

#### Step 2: Clone and Setup
```bash
# Clone repository
git clone https://github.com/kasbahcode/devops-toolkit.git
cd devops-toolkit

# Run setup
chmod +x scripts/*.sh
./scripts/setup.sh
```

### Linux-Specific Notes
- **SELinux**: May need to configure SELinux policies for Docker
- **Firewall**: Configure firewall rules for Docker and applications
- **Systemd**: Docker service is managed by systemd

---

## 🪟 Windows Installation

### Option 1: Windows Subsystem for Linux (WSL2) - Recommended

#### Step 1: Enable WSL2
```powershell
# Open PowerShell as Administrator and run:
wsl --install

# Restart your computer
```

#### Step 2: Install Ubuntu from Microsoft Store
1. Open Microsoft Store
2. Search for "Ubuntu"
3. Install Ubuntu 20.04 LTS or newer
4. Launch Ubuntu and complete setup

#### Step 3: Install DevOps Toolkit in WSL2
```bash
# Inside Ubuntu WSL terminal:
sudo apt update && sudo apt upgrade -y
sudo apt install -y git

# Clone and setup
git clone https://github.com/kasbahcode/devops-toolkit.git
cd devops-toolkit
chmod +x scripts/*.sh
./scripts/setup.sh
```

### Option 2: Windows Native (Advanced Users)

#### Step 1: Install Git for Windows
```bash
# Download and install from:
# https://git-scm.com/download/win
```

#### Step 2: Install Docker Desktop
```bash
# Download and install from:
# https://www.docker.com/products/docker-desktop
```

#### Step 3: Clone Repository
```bash
# In Git Bash or PowerShell:
git clone https://github.com/kasbahcode/devops-toolkit.git
cd devops-toolkit
```

#### Step 4: Run PowerShell Setup
```powershell
# Run in PowerShell as Administrator:
.\scripts\setup.ps1
```

### Windows-Specific Notes
- **WSL2 Performance**: Better performance than Windows native
- **File System**: Use WSL2 file system for better Docker performance
- **Antivirus**: May need to exclude Docker directories from scanning
- **Hyper-V**: Required for Docker Desktop

---

## 🐳 Docker Desktop Setup

### Installation Verification
```bash
# Check Docker version
docker --version
docker-compose --version

# Test Docker installation
docker run hello-world

# Check Docker system info
docker system info
```

### Docker Desktop Configuration

#### Memory and CPU Settings
1. Open Docker Desktop settings
2. Go to Resources → Advanced
3. Set RAM: 4GB minimum (8GB recommended)
4. Set CPU: 2 cores minimum (4 cores recommended)

#### Enable Kubernetes (Optional)
1. Go to Settings → Kubernetes
2. Check "Enable Kubernetes"
3. Click "Apply & Restart"

#### File Sharing (Important)
1. Go to Settings → Resources → File Sharing
2. Add your project directory path
3. Click "Apply & Restart"

### Docker Commands Verification
```bash
# Test Docker functionality
docker run --rm alpine echo "Docker is working!"

# Test Docker Compose
docker-compose --version

# Test Docker networking
docker network ls

# Test Docker volumes
docker volume ls
```

---

## ✅ Verification Steps

### Complete System Check
```bash
# Run comprehensive health check
./scripts/monitor.sh health

# This checks:
# - Docker installation
# - Node.js and npm
# - Python and pip
# - kubectl
# - Terraform
# - Ansible
# - Network connectivity
```

### Manual Verification

#### Check Git
```bash
git --version
# Expected: git version 2.30+
```

#### Check Docker
```bash
docker --version
# Expected: Docker version 20.10+

docker-compose --version
# Expected: docker-compose version 1.29+
```

#### Check Node.js
```bash
node --version
# Expected: v18.0+

npm --version
# Expected: 8.0+
```

#### Check Kubernetes Tools
```bash
kubectl version --client
# Expected: Client Version info

terraform --version
# Expected: Terraform v1.0+

ansible --version
# Expected: ansible [core 2.12+]
```

### Test Project Creation
```bash
# Create a test project
./scripts/init-project.sh test-installation
cd ../test-installation

# Start the project
docker-compose up -d

# Check if services are running
docker-compose ps

# Clean up
docker-compose down
cd ../devops-toolkit
rm -rf ../test-installation
```

---

## 🔧 Troubleshooting

### Common Issues and Solutions

#### Issue 1: Permission Denied on Scripts
```bash
# Solution: Make scripts executable
chmod +x scripts/*.sh
chmod +x ssl/*.sh
chmod +x database/*.sh
chmod +x security/*.sh
```

#### Issue 2: Docker Permission Denied (Linux)
```bash
# Solution: Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Test Docker access
docker run hello-world
```

#### Issue 3: Port Already in Use
```bash
# Solution: Check what's using the port
sudo lsof -i :3000
sudo lsof -i :9090

# Kill the process or change ports in docker-compose.yml
sudo kill -9 <PID>
```

#### Issue 4: WSL2 Docker Issues (Windows)
```bash
# Solution: Restart Docker Desktop and WSL2
wsl --shutdown
# Restart Docker Desktop from Windows

# Verify WSL2 integration
wsl -l -v
```

#### Issue 5: Out of Disk Space
```bash
# Solution: Clean up Docker
docker system prune -a
docker volume prune

# Check disk usage
df -h
```

#### Issue 6: Network Issues
```bash
# Solution: Check network connectivity
ping google.com
nslookup google.com

# Check Docker networking
docker network ls
docker network inspect bridge
```

#### Issue 7: Memory Issues
```bash
# Solution: Increase Docker memory allocation
# In Docker Desktop: Settings → Resources → Advanced
# Set memory to at least 4GB

# Check system memory
free -h  # Linux
top      # macOS/Linux
```

### Advanced Troubleshooting

#### Enable Debug Mode
```bash
# Enable debug logging
export DEBUG=true
export VERBOSE=true

# Run with debug output
./scripts/setup.sh --debug
```

#### Check System Logs
```bash
# macOS
tail -f /var/log/system.log

# Linux
journalctl -f
sudo tail -f /var/log/syslog

# Docker logs
docker logs <container_name>
```

#### Network Diagnostics
```bash
# Check port availability
netstat -tulpn | grep :3000

# Test Docker networking
docker run --rm alpine ping google.com

# Check DNS resolution
nslookup github.com
```

---

## ⚙️ Advanced Configuration

### Custom Installation Paths
```bash
# Set custom installation directory
export DEVOPS_TOOLKIT_HOME=/custom/path
./scripts/setup.sh --custom-path $DEVOPS_TOOLKIT_HOME
```

### Proxy Configuration
```bash
# Configure proxy settings
export HTTP_PROXY=http://proxy.company.com:8080
export HTTPS_PROXY=http://proxy.company.com:8080
export NO_PROXY=localhost,127.0.0.1

# Docker proxy configuration
mkdir -p ~/.docker
cat > ~/.docker/config.json << EOF
{
  "proxies": {
    "default": {
      "httpProxy": "$HTTP_PROXY",
      "httpsProxy": "$HTTPS_PROXY",
      "noProxy": "$NO_PROXY"
    }
  }
}
EOF
```

### Offline Installation
```bash
# Download dependencies for offline installation
./scripts/setup.sh --download-only --offline-cache ./offline-cache

# Install from offline cache
./scripts/setup.sh --offline --cache-dir ./offline-cache
```

### Development Environment
```bash
# Set up development mode
./scripts/setup.sh --dev-mode

# This enables:
# - Additional development tools
# - Hot reloading
# - Debug configurations
# - Test dependencies
```

---

## 🔄 Post-Installation Steps

### 1. Configure Git (if not already done)
```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

### 2. Set Up SSH Keys (for deployment)
```bash
# Generate SSH key
ssh-keygen -t rsa -b 4096 -C "your.email@example.com"

# Add to SSH agent
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_rsa
```

### 3. Configure AWS CLI (for cloud deployment)
```bash
# Install AWS CLI (if not already installed)
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Configure AWS credentials
aws configure
```

### 4. Set Up Environment Variables
```bash
# Create .env file
cp .env.template .env

# Edit with your settings
nano .env
```

### 5. Test Complete Installation
```bash
# Create and run a complete test project
./scripts/init-project.sh installation-test
cd ../installation-test

# Start all services
docker-compose up -d

# Run health checks
./scripts/monitor.sh health

# Access test application
curl http://localhost:3000

# Clean up
docker-compose down
cd ../devops-toolkit
rm -rf ../installation-test
```

---

## 📞 Getting Help

### 🆓 **Free Support Options**

#### If Installation Fails:
1. **Check System Requirements**: Ensure your system meets minimum requirements
2. **Review Error Messages**: Look for specific error messages in the output
3. **Check Logs**: Examine installation logs in `logs/setup.log`
4. **Community Support**: 
   - GitHub Issues: Report installation problems
   - Discussions: Ask questions and get help
   - Documentation: Check component-specific docs

#### Free Support Channels:
- 🐛 **Bug Reports**: [GitHub Issues](https://github.com/kasbahcode/devops-toolkit/issues)
- 💬 **Questions**: [GitHub Discussions](https://github.com/kasbahcode/devops-toolkit/discussions)
- 📖 **Wiki**: Detailed documentation and guides

### 💎 **Professional Installation Services**

#### 🚀 **Express Setup Service** - $2K-5K
**Perfect for:** Teams who want professional installation without the hassle

**What's Included:**
- ✅ **Remote installation** on your systems
- ✅ **Custom environment configuration**
- ✅ **Production-ready setup**
- ✅ **Security hardening**
- ✅ **SSL certificate setup**
- ✅ **Monitoring configuration**
- ✅ **Knowledge transfer session**
- ✅ **30-day email support**

**Timeline:** 1 week from start to finish

#### 🏢 **Enterprise Implementation** - $5K-15K
**Perfect for:** Companies needing multi-environment setup

**What's Included:**
- ✅ **Multi-environment setup** (dev/staging/prod)
- ✅ **Advanced security configuration**
- ✅ **Custom monitoring dashboards**
- ✅ **CI/CD pipeline setup**
- ✅ **Database optimization**
- ✅ **Load balancer configuration**
- ✅ **Team training session**
- ✅ **90-day support package**

**Timeline:** 2-3 weeks with dedicated project manager

#### 🎯 **Why Choose Professional Installation?**
- **⏰ Save Time**: Skip the learning curve, get running immediately
- **🛡️ Security First**: Professional security hardening from day one
- **📈 Best Practices**: Enterprise-grade configuration out of the box
- **🎓 Knowledge Transfer**: Learn from experts during implementation
- **💪 Ongoing Support**: Don't get stuck - we're here to help

#### 🎁 **Special Offers**
- **✨ Free consultation** to assess your needs
- **🚀 20% discount** for first 100 clients
- **👥 Team discounts** for multiple team members
- **📈 Startup pricing** - 50% off for companies < 2 years old

### 📞 **Get Professional Help**
- 📧 **Email**: devops@kasbahcode.com
- 📞 **Book Consultation**: [Schedule Free Call](https://calendly.com/kasbahcode/devops-consultation)
- 💬 **Live Chat**: Available 9 AM - 6 PM EST

**🏆 Success Guarantee:** Money-back guarantee if not satisfied within 30 days

---

**🎉 Congratulations!** 

You've successfully installed the DevOps Toolkit. You're now ready to create professional, production-ready applications with enterprise-grade DevOps practices.

**Next Steps:**
1. 📖 Read the [USE-CASES.md](USE-CASES.md) guide
2. 🚀 Create your first project: `./scripts/init-project.sh my-first-app`
3. 🌟 Star us on GitHub if this toolkit helps you!

*Remember: Great DevOps starts with great tools. You now have them all!* 