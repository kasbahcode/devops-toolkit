#!/bin/bash

# 🚀 Project Initialization Script
# Creates a new project with DevOps best practices
# (I use this script for all my projects now - saves hours of setup)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Version info
SCRIPT_VERSION="2.1.3"
LAST_UPDATED="2024-01-15"

# Logging functions
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    echo -e "${RED}💡 Tip: Check the troubleshooting section in docs/FAQ.md${NC}"
    exit 1
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

debug() {
    if [[ "${DEBUG:-false}" == "true" ]]; then
        echo -e "${PURPLE}[DEBUG] $1${NC}"
    fi
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# Show a cool header
show_header() {
    echo -e "${GREEN}"
    cat << 'EOF'
    ██╗███╗   ██╗██╗████████╗    ██████╗ ██████╗  ██████╗      ██╗███████╗ ██████╗████████╗
    ██║████╗  ██║██║╚══██╔══╝    ██╔══██╗██╔══██╗██╔═══██╗     ██║██╔════╝██╔════╝╚══██╔══╝
    ██║██╔██╗ ██║██║   ██║       ██████╔╝██████╔╝██║   ██║     ██║█████╗  ██║        ██║   
    ██║██║╚██╗██║██║   ██║       ██╔═══╝ ██╔══██╗██║   ██║██   ██║██╔══╝  ██║        ██║   
    ██║██║ ╚████║██║   ██║       ██║     ██║  ██║╚██████╔╝╚█████╔╝███████╗╚██████╗   ██║   
    ╚═╝╚═╝  ╚═══╝╚═╝   ╚═╝       ╚═╝     ╚═╝  ╚═╝ ╚═════╝  ╚════╝ ╚══════╝ ╚═════╝   ╚═╝   
EOF
    echo -e "${NC}"
    echo -e "${BLUE}DevOps Toolkit Project Generator v${SCRIPT_VERSION}${NC}"
    echo -e "${PURPLE}Because life's too short for manual setup 🚀${NC}"
    echo ""
}

# Help function
show_help() {
    cat << EOF
DevOps Toolkit - Project Scaffolder v${SCRIPT_VERSION}

USAGE:
    $0 [OPTIONS] <project-name>

ARGUMENTS:
    <project-name>      Name of the project to create

OPTIONS:
    -h, --help          Show this help message
    -t, --template      Project template (nodejs|python|go|static) [default: nodejs]
    -d, --database      Database type (postgres|mysql|mongodb|none) [default: postgres]
    -m, --monitoring    Include monitoring stack
    --debug             Enable debug output

TEMPLATES:
    nodejs      Express.js API with security best practices
    python      FastAPI application with async support
    go          Gin web service with middleware
    static      Static site with CI/CD pipeline

DATABASES:
    postgres    PostgreSQL with connection pooling
    mysql       MySQL with proper indexing
    mongodb     MongoDB with ODM integration
    none        No database configuration

EXAMPLES:
    $0 my-api                              # Create Node.js API with PostgreSQL
    $0 -t python -d mongodb my-service     # Create Python service with MongoDB
    $0 -t static -d none my-site          # Create static site
    $0 -m --debug my-app                  # Create with monitoring and debug output

PROJECT STRUCTURE:
    project-name/
    ├── src/                # Application source code
    ├── scripts/            # Deployment and utility scripts
    ├── k8s/               # Kubernetes manifests
    ├── .github/           # CI/CD workflows
    ├── docker-compose.yml # Local development
    ├── Dockerfile         # Container image
    └── README.md          # Project documentation

For more information, visit: https://github.com/kasbahcode/devops-toolkit
EOF
}

# Parse command line arguments
parse_args() {
    # Set defaults
    PROJECT_NAME=""
    TEMPLATE="nodejs"
    DATABASE_TYPE="postgres"
    INCLUDE_MONITORING="false"
    DEBUG="false"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -t|--template)
                TEMPLATE="$2"
                shift 2
                ;;
            -d|--database)
                DATABASE_TYPE="$2"
                shift 2
                ;;
            -m|--monitoring)
                INCLUDE_MONITORING="true"
                shift
                ;;
            --debug)
                DEBUG="true"
                shift
                ;;
            -*)
                error "Unknown option $1"
                ;;
            *)
                if [ -z "$PROJECT_NAME" ]; then
                    PROJECT_NAME="$1"
                else
                    error "Too many arguments. Project name: $PROJECT_NAME, extra: $1"
                fi
                shift
                ;;
        esac
    done
    
    # Validate project name
    if [ -z "$PROJECT_NAME" ]; then
        error "Project name is required. Use --help for usage information."
    fi
    
    # Validate template
    if [[ ! "$TEMPLATE" =~ ^(nodejs|python|go|static)$ ]]; then
        error "Invalid template: $TEMPLATE. Valid templates: nodejs, python, go, static"
    fi
    
    # Validate database type
    if [[ ! "$DATABASE_TYPE" =~ ^(postgres|mysql|mongodb|none)$ ]]; then
        error "Invalid database: $DATABASE_TYPE. Valid databases: postgres, mysql, mongodb, none"
    fi
}

# Check system dependencies
check_dependencies() {
    local missing=()
    
    # Check for required tools
    command -v docker >/dev/null 2>&1 || missing+=("docker")
    command -v git >/dev/null 2>&1 || missing+=("git")
    
    # Check for template-specific dependencies
    case "$TEMPLATE" in
        nodejs)
            command -v node >/dev/null 2>&1 || missing+=("nodejs")
            command -v npm >/dev/null 2>&1 || missing+=("npm")
            ;;
        python)
            command -v python3 >/dev/null 2>&1 || missing+=("python3")
            command -v pip3 >/dev/null 2>&1 || missing+=("pip3")
            ;;
        go)
            command -v go >/dev/null 2>&1 || missing+=("go")
            ;;
    esac
    
    if [ ${#missing[@]} -ne 0 ]; then
        error "Missing required dependencies: ${missing[*]}"
        echo "Please run ./scripts/setup.sh to install dependencies"
        exit 1
    fi
}

# Create base project structure
create_base_structure() {
    log "🏗️  Creating project structure..."
    
    # Create directory structure
    mkdir -p {src,scripts,k8s,tests,.github/workflows,docs}
    
    # Create basic files
    touch .env.example
    touch README.md
    
    log "📁 Created base project structure"
}

# Create .gitignore
create_gitignore() {
    cat > .gitignore << 'EOF'
# Dependencies and packages
node_modules/
npm-debug.log*
yarn-debug.log*
*.pyc
__pycache__/
vendor/
go.sum

# Environment and secrets (learned this the hard way)
.env
.env.*
!.env.example
*.key
*.pem
config.local.*

# Build outputs
dist/
build/
target/
*.exe

# Editor and OS files
.vscode/
.idea/
*.swp
.DS_Store
Thumbs.db

# Docker
.docker/
docker-compose.override.yml

# Logs and temp files
logs/
*.log
tmp/
.cache/

# Database
*.db
*.sqlite

# Don't commit these (trust me)
backup/
security-reports/
kubeconfig*
*secret*
EOF
}

# Create Node.js project
create_nodejs_project() {
    log "📦 Setting up Node.js project..."
    
    # Create package.json
    cat > package.json << EOF
{
  "name": "$PROJECT_NAME",
  "version": "1.0.0",
  "description": "A production-ready Node.js application",
  "main": "src/index.js",
  "scripts": {
    "start": "node src/index.js",
    "dev": "nodemon src/index.js --ignore tests/",
    "test": "jest --coverage",
    "lint": "eslint src/ tests/",
    "format": "prettier --write src/ tests/",
    "build": "npm run build:docker",
    "build:docker": "docker build -t $PROJECT_NAME .",
    "deploy": "kubectl apply -f k8s/"
  },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "helmet": "^7.1.0",
    "dotenv": "^16.3.1",
    "express-rate-limit": "^7.1.5",
    "compression": "^1.7.4",
    "morgan": "^1.10.0"
  },
  "devDependencies": {
    "nodemon": "^3.0.2",
    "jest": "^29.7.0",
    "eslint": "^8.56.0",
    "prettier": "^3.1.1"
  }
}
EOF

    # Create main application file
    cat > src/index.js << 'EOF'
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const compression = require('compression');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;
const NODE_ENV = process.env.NODE_ENV || 'development';

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: NODE_ENV === 'production' ? 100 : 1000,
  message: 'Too many requests, please try again later.'
});

// Middleware
app.use(helmet());
app.use(compression());
app.use(morgan(NODE_ENV === 'production' ? 'combined' : 'dev'));
app.use(limiter);
app.use(cors());
app.use(express.json({ limit: '10mb' }));

// Health check
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

// Main route
app.get('/', (req, res) => {
  res.json({
    message: `Welcome to PROJECT_NAME! 🚀`,
    version: '1.0.0',
    environment: NODE_ENV
  });
});

// Start server
app.listen(PORT, () => {
  console.log(`🚀 Server running on port ${PORT}`);
  console.log(`📊 Health check: http://localhost:${PORT}/health`);
});

module.exports = app;
EOF

    # Replace placeholder
    sed -i.bak "s/PROJECT_NAME/$PROJECT_NAME/g" src/index.js && rm src/index.js.bak
}

# Create Python project
create_python_project() {
    log "🐍 Setting up Python project..."
    
    cat > requirements.txt << 'EOF'
fastapi==0.104.1
uvicorn==0.24.0
pydantic==2.5.0
python-dotenv==1.0.0
httpx==0.25.2
pytest==7.4.3
pytest-asyncio==0.21.1
EOF

    cat > src/main.py << 'EOF'
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
import uvicorn
import os
from dotenv import load_dotenv

load_dotenv()

app = FastAPI(
    title="PROJECT_NAME",
    description="A production-ready FastAPI application",
    version="1.0.0"
)

# Middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.add_middleware(GZipMiddleware, minimum_size=1000)

@app.get("/")
async def root():
    return {
        "message": "Welcome to PROJECT_NAME! 🚀",
        "version": "1.0.0"
    }

@app.get("/health")
async def health_check():
    return {"status": "healthy"}

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=int(os.getenv("PORT", 8000)),
        reload=True
    )
EOF

    # Replace placeholder
    sed -i.bak "s/PROJECT_NAME/$PROJECT_NAME/g" src/main.py && rm src/main.py.bak
}

# Create Go project
create_go_project() {
    log "🐹 Setting up Go project..."
    
    cat > go.mod << EOF
module $PROJECT_NAME

go 1.21

require (
    github.com/gin-gonic/gin v1.9.1
    github.com/joho/godotenv v1.4.0
)
EOF

    cat > src/main.go << 'EOF'
package main

import (
    "net/http"
    "os"
    "github.com/gin-gonic/gin"
    "github.com/joho/godotenv"
)

func main() {
    godotenv.Load()
    
    r := gin.Default()
    
    r.GET("/", func(c *gin.Context) {
        c.JSON(http.StatusOK, gin.H{
            "message": "Welcome to PROJECT_NAME! 🚀",
            "version": "1.0.0",
        })
    })
    
    r.GET("/health", func(c *gin.Context) {
        c.JSON(http.StatusOK, gin.H{
            "status": "healthy",
        })
    })
    
    port := os.Getenv("PORT")
    if port == "" {
        port = "8080"
    }
    
    r.Run(":" + port)
}
EOF

    # Replace placeholder
    sed -i.bak "s/PROJECT_NAME/$PROJECT_NAME/g" src/main.go && rm src/main.go.bak
}

# Create static site project
create_static_project() {
    log "🌐 Setting up static site..."
    
    cat > src/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PROJECT_NAME</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 0; padding: 20px; }
        .container { max-width: 800px; margin: 0 auto; text-align: center; }
        .header { color: #333; margin-bottom: 20px; }
    </style>
</head>
<body>
    <div class="container">
        <h1 class="header">Welcome to PROJECT_NAME! 🚀</h1>
        <p>This is a production-ready static site.</p>
    </div>
</body>
</html>
EOF

    # Replace placeholder
    sed -i.bak "s/PROJECT_NAME/$PROJECT_NAME/g" src/index.html && rm src/index.html.bak
}

# Create environment file
create_env_file() {
    log "🔐 Creating environment file..."
    
    cat > .env.example << EOF
# Application Configuration
NODE_ENV=development
PORT=3000
SERVICE_NAME=$PROJECT_NAME
VERSION=1.0.0

# Database Configuration
DATABASE_URL=postgresql://postgres:password@localhost:5432/$PROJECT_NAME

# Security
JWT_SECRET=your-super-secret-jwt-key-here
ALLOWED_ORIGINS=http://localhost:3000

# External APIs
API_KEY=your-api-key-here
EOF
}

# Create Docker configuration
create_docker_config() {
    log "🐳 Creating Docker configuration..."
    
    case "$TEMPLATE" in
        nodejs)
            cat > Dockerfile << 'EOF'
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY src/ ./src/

EXPOSE 3000

USER node

CMD ["npm", "start"]
EOF
            ;;
        python)
            cat > Dockerfile << 'EOF'
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY src/ ./src/

EXPOSE 8000

CMD ["python", "src/main.py"]
EOF
            ;;
        go)
            cat > Dockerfile << 'EOF'
FROM golang:1.21-alpine AS builder

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download

COPY src/ ./src/
RUN go build -o main src/main.go

FROM alpine:latest
RUN apk --no-cache add ca-certificates
WORKDIR /root/

COPY --from=builder /app/main .

EXPOSE 8080

CMD ["./main"]
EOF
            ;;
        static)
            cat > Dockerfile << 'EOF'
FROM nginx:alpine

COPY src/ /usr/share/nginx/html/

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
EOF
            ;;
    esac
}

# Create README
create_readme() {
    log "📚 Creating README..."
    
    cat > README.md << EOF
# $PROJECT_NAME

A production-ready application built with the DevOps Toolkit.

## Quick Start

\`\`\`bash
# Copy environment file
cp .env.example .env

# Install dependencies and start
docker-compose up -d
\`\`\`

## Development

\`\`\`bash
# Install dependencies
npm install  # or pip install -r requirements.txt

# Start development server
npm run dev  # or python src/main.py

# Run tests
npm test     # or pytest
\`\`\`

## Deployment

\`\`\`bash
# Deploy to Kubernetes
kubectl apply -f k8s/

# Or use Docker
docker build -t $PROJECT_NAME .
docker run -p 3000:3000 $PROJECT_NAME
\`\`\`

## Features

- 🚀 Production-ready configuration
- 🔒 Security best practices
- 📊 Health checks and monitoring
- 🐳 Docker support
- ☸️ Kubernetes manifests
- 🔄 CI/CD pipeline

## License

MIT
EOF
}

# Main execution function
main() {
    show_header
    
    check_dependencies
    
    # Create project directory
    if [ ! -d "$PROJECT_NAME" ]; then
        mkdir -p "$PROJECT_NAME"
    fi
    
    cd "$PROJECT_NAME"
    PROJECT_DIR="$(pwd)"
    
    success "🎯 Setting up project in: $PROJECT_DIR"
    
    # Initialize git if not already initialized
    if [ ! -d ".git" ]; then
        git init
        log "📝 Initialized git repository"
    fi
    
    # Create base structure
    create_base_structure
    create_gitignore
    create_env_file
    create_docker_config
    create_readme
    
    # Create project based on template
    case "$TEMPLATE" in
        nodejs)
            create_nodejs_project
            ;;
        python)
            create_python_project
            ;;
        go)
            create_go_project
            ;;
        static)
            create_static_project
            ;;
    esac
    
    success "🎉 Project '$PROJECT_NAME' created successfully!"
    
    echo
    echo "📋 Next steps:"
    echo "   cd $PROJECT_NAME"
    echo "   cp .env.example .env"
    case "$TEMPLATE" in
        nodejs)
            echo "   npm install"
            echo "   npm run dev"
            ;;
        python)
            echo "   pip install -r requirements.txt"
            echo "   python src/main.py"
            ;;
        go)
            echo "   go mod tidy"
            echo "   go run src/main.go"
            ;;
        static)
            echo "   # Open src/index.html in browser"
            ;;
    esac
    echo
    echo "🌐 Your app will be available at http://localhost:3000"
    echo
    echo "💡 Pro tip: Edit .env file with your actual values before starting!"
}

# Parse arguments and run
parse_args "$@"
main 