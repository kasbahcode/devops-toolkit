# DevOps Toolkit
### *The toolkit I built because I was tired of paying $3K/month for tools that don't play nice together*

> **Why I built this:** After years of wrestling with expensive DevOps tools that promised everything but delivered integration headaches, I spent my evenings and weekends building something that actually works. No BS marketing, no vendor lock-in, just solid automation that gets the job done. - *Mouad*

A complete DevOps automation platform that replaces multiple expensive SaaS tools with one integrated solution. Built by a developer who got tired of overpaying for basic functionality.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## What You Actually Get (No Marketing BS)

**Monitoring that doesn't suck:**
- Prometheus + Grafana + AlertManager (properly configured, not just installed)
- ELK stack for logs that you can actually search through
- Jaeger for tracing (because distributed systems are hard)
- Redis + PostgreSQL monitoring that catches issues before your users do
- Dashboards with metrics that matter, not vanity numbers

**Security scanning that finds real problems:**
- Trivy, Semgrep, and CodeQL working together (took me weeks to get this right)
- Container scanning that catches vulnerabilities before deployment
- Secrets detection (learned this the hard way after almost committing API keys)
- Infrastructure scanning with actual remediation steps
- Compliance monitoring for HIPAA/SOC2 (if you're into that sort of thing)

**AWS infrastructure that scales:**
- EKS cluster that doesn't cost a fortune
- RDS PostgreSQL + ElastiCache Redis (because DIY databases are pain)
- Auto-scaling that actually works under load
- S3 + CloudWatch integration
- VPC setup that doesn't leave security holes

**CI/CD pipeline that deploys with confidence:**
- Multi-stage security scanning (because security should be automatic)
- Automated testing that catches bugs before production
- Container building with vulnerability scanning
- Blue-green deployments with automatic rollback
- Load testing integration (because "it works on my machine" isn't enough)

**Project scaffolding that follows best practices:**
- Express.js apps with security headers and proper middleware
- Database migrations that don't break production
- Kubernetes manifests that actually work
- SSL certificates that renew automatically
- Security hardening based on real-world experience

## Quick Start (Seriously, It's This Easy)

```bash
# 1. Clone the repository
git clone https://github.com/kasbahcode/devops-toolkit.git
cd devops-toolkit

# 2. Run the guided onboarding (recommended for new users)
./scripts/client-onboarding.sh

# 3. Or run manual setup
./scripts/setup.sh
./scripts/init-project.sh my-app
```

Your app runs at `http://localhost:3000` with monitoring at `http://localhost:3001`

**🎯 First time user?** The `client-onboarding.sh` script will guide you through everything!

## What These Scripts Actually Do

- `setup.sh` - Installs Docker, Node.js, kubectl, Terraform, and friends (handles macOS/Linux differences)
- `init-project.sh` - Creates real applications, not toy examples
- `deploy.sh` - Deploys to staging/production with health checks (no YOLO deployments)
- `monitor.sh` - Shows you what's actually happening in your infrastructure
- `backup.sh` - Automated backups to S3 (because disasters happen)
- `security-scan.sh` - Multi-tool security scanning with actionable reports

## Who This Is For

- **Startups** tired of $5K/month DevOps bills eating into runway
- **Scale-ups** that need enterprise features without enterprise bureaucracy
- **Development teams** who want to ship features, not fight infrastructure
- **DevOps engineers** who like automation that actually automates
- **CTOs** evaluating cost-effective alternatives to vendor lock-in

**Not for:** People who've never used Docker or don't know what Kubernetes is.

## System Requirements (The Real Talk)

- macOS, Linux, or Windows with WSL2
- 8GB RAM minimum (16GB if you want the full monitoring stack without tears)
- 20GB disk space (containers add up fast)
- Decent internet connection (lots of Docker images to download)
- Basic understanding of command line (this isn't a GUI tool)

## What This Actually Replaces

| What You're Probably Paying For | Monthly Damage | What You Get Instead |
|--------------------------------|---------------|---------------------|
| DataDog Enterprise | $600-2K | Complete monitoring with Prometheus/Grafana |
| CircleCI Pro | $500-1.5K | GitHub Actions with security scanning |
| Snyk Enterprise | $500-1K | Multi-tool security scanning |
| Terraform Cloud | $300-800 | Infrastructure as code with state management |
| **Annual savings** | **$23K-63K** | **$0 (plus your sanity)** |

## The Real Architecture

```
What You're Actually Getting:
├── Monitoring Stack (Prometheus, Grafana, ELK - configured properly)
├── Security Suite (Trivy, Semgrep, CodeQL - integrated, not just installed)
├── AWS Infrastructure (EKS, RDS, Redis, S3 - production-ready configs)
├── CI/CD Pipeline (GitHub Actions with actual security gates)
├── Application Platform (Node.js, Python, Go templates that work)
└── Operations Tools (Ansible, backup scripts, load testing)
```

## When Things Go Wrong (They Will)

**Docker won't start?**
- macOS: Make sure Docker Desktop is actually running (`open -a Docker`)
- Linux: `sudo systemctl start docker`
- Windows: Try restarting WSL (`wsl --shutdown`)

**Port conflicts driving you crazy?**
- Find the culprit: `lsof -i :3000`
- Kill it: `sudo kill -9 <PID>`
- Or edit `docker-compose.yml` to use different ports

**Running out of memory?**
- Docker Desktop: Bump memory to 8GB in settings
- Linux: Close Chrome (seriously, it's probably Chrome)

**Kubernetes being weird?**
- `kubectl get pods --all-namespaces` to see what's actually running
- `kubectl describe pod <pod-name>` for the full story
- When in doubt: `kubectl delete pod <pod-name>` and let it restart

## What's Actually Included

```
📁 Your New DevOps Superpowers
├── 📊 monitoring/          # Prometheus, Grafana, ELK (pre-configured)
├── 🔒 security/           # Multi-tool scanning (integrated properly)
├── ☁️ terraform/          # AWS infrastructure (battle-tested)
├── 🔄 ci-cd/             # GitHub Actions (with security gates)
├── ☸️ kubernetes/         # K8s manifests (that actually work)
├── 🗄️ database/          # Migrations and backups (automated)
├── 🔧 scripts/           # Deployment automation (no manual steps)
├── 📋 ansible/           # Server config management
├── 🧪 tests/             # Load testing with k6
└── 🔐 ssl/               # Certificate management (auto-renewal)
```

## Getting Help

- Check the `docs/` folder first (I actually use these guides)
- GitHub Issues for bugs (include error logs, please)
- Email me at devops@kasbahcode.com for implementation help (I do consulting)

**Pro tip:** Most "bugs" are actually Docker not having enough memory or ports being occupied. Check those first.

## License

MIT License - use it for whatever you want. If you make money with it, consider buying me a coffee ☕

---

*Built by someone who believes DevOps tools should work together, not against each other.*

 # devops-toolkit
