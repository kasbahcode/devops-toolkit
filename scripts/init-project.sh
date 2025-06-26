#!/bin/bash

# 🚀 Project Initialization Script
# Creates a new project with DevOps best practices

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging function
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

# Check if project name is provided
if [ -z "$1" ]; then
    error "Please provide a project name: ./init-project.sh my-awesome-app"
fi

PROJECT_NAME="$1"
PROJECT_DIR="../$PROJECT_NAME"

log "🚀 Initializing project: $PROJECT_NAME"

# Create project directory
if [ -d "$PROJECT_DIR" ]; then
    error "Project directory $PROJECT_DIR already exists"
fi

mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

# Initialize git repository
log "📦 Initializing Git repository..."
git init
git branch -M main

# Create project structure
log "📁 Creating project structure..."
mkdir -p {src,tests,docs,scripts,docker,k8s,monitoring,.github/workflows}

# Create package.json for Node.js projects
log "📄 Creating package.json..."
cat > package.json << EOF
{
  "name": "$PROJECT_NAME",
  "version": "1.0.0",
  "description": "A new project created with DevOps Toolkit",
  "main": "src/index.js",
  "scripts": {
    "start": "node src/index.js",
    "dev": "nodemon src/index.js",
    "test": "jest",
    "build": "npm run build:docker",
    "build:docker": "docker build -t $PROJECT_NAME .",
    "deploy": "kubectl apply -f k8s/",
    "lint": "eslint src/",
    "format": "prettier --write src/"
  },
  "keywords": ["devops", "automation"],
  "author": "DevOps Toolkit",
  "license": "MIT",
  "devDependencies": {
    "nodemon": "^3.0.0",
    "jest": "^29.0.0",
    "eslint": "^8.0.0",
    "prettier": "^3.0.0"
  },
  "dependencies": {
    "express": "^4.18.0",
    "cors": "^2.8.5",
    "helmet": "^7.0.0",
    "dotenv": "^16.0.0"
  }
}
EOF

# Create Dockerfile
log "🐳 Creating Dockerfile..."
cat > Dockerfile << EOF
# Multi-stage build for Node.js application
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production && npm cache clean --force

# Copy source code
COPY src/ ./src/

# Production stage
FROM node:18-alpine AS production

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \\
    adduser -S -u 1001 -G nodejs nodejs

WORKDIR /app

# Copy from builder stage
COPY --from=builder --chown=nodejs:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=nodejs:nodejs /app/package*.json ./
COPY --from=builder --chown=nodejs:nodejs /app/src ./src

# Switch to non-root user
USER nodejs

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \\
  CMD curl -f http://localhost:3000/health || exit 1

# Start the application
CMD ["npm", "start"]
EOF

# Create docker-compose.yml
log "🔧 Creating docker-compose.yml..."
cat > docker-compose.yml << EOF
version: '3.8'

services:
  app:
    build: .
    container_name: ${PROJECT_NAME}-app
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=development
      - PORT=3000
    volumes:
      - ./src:/app/src
      - /app/node_modules
    depends_on:
      - redis
      - postgres
    networks:
      - app-network
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    container_name: ${PROJECT_NAME}-redis
    ports:
      - "6379:6379"
    volumes:
      - redis-data:/data
    networks:
      - app-network
    restart: unless-stopped

  postgres:
    image: postgres:15-alpine
    container_name: ${PROJECT_NAME}-postgres
    environment:
      POSTGRES_DB: ${PROJECT_NAME}
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: password123
    ports:
      - "5432:5432"
    volumes:
      - postgres-data:/var/lib/postgresql/data
    networks:
      - app-network
    restart: unless-stopped

volumes:
  redis-data:
  postgres-data:

networks:
  app-network:
    driver: bridge
EOF

# Create basic Express.js app
log "⚡ Creating Express.js application..."
cat > src/index.js << EOF
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(helmet());
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'OK',
    timestamp: new Date().toISOString(),
    service: '$PROJECT_NAME'
  });
});

// Main route
app.get('/', (req, res) => {
  res.json({
    message: 'Welcome to $PROJECT_NAME!',
    version: '1.0.0',
    environment: process.env.NODE_ENV || 'development'
  });
});

// API routes
app.get('/api/status', (req, res) => {
  res.json({
    status: 'running',
    uptime: process.uptime(),
    memory: process.memoryUsage(),
    pid: process.pid
  });
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({
    error: 'Something went wrong!',
    message: process.env.NODE_ENV === 'development' ? err.message : 'Internal Server Error'
  });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({
    error: 'Route not found',
    path: req.originalUrl
  });
});

app.listen(PORT, () => {
  console.log(\`🚀 Server running on port \${PORT}\`);
  console.log(\`📊 Health check: http://localhost:\${PORT}/health\`);
});

module.exports = app;
EOF

# Create Kubernetes manifests
log "☸️ Creating Kubernetes manifests..."
mkdir -p k8s

cat > k8s/namespace.yaml << EOF
apiVersion: v1
kind: Namespace
metadata:
  name: $PROJECT_NAME
  labels:
    name: $PROJECT_NAME
EOF

cat > k8s/deployment.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $PROJECT_NAME-app
  namespace: $PROJECT_NAME
  labels:
    app: $PROJECT_NAME
spec:
  replicas: 3
  selector:
    matchLabels:
      app: $PROJECT_NAME
  template:
    metadata:
      labels:
        app: $PROJECT_NAME
    spec:
      containers:
      - name: $PROJECT_NAME
        image: $PROJECT_NAME:latest
        ports:
        - containerPort: 3000
        env:
        - name: NODE_ENV
          value: "production"
        - name: PORT
          value: "3000"
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
        livenessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: $PROJECT_NAME-service
  namespace: $PROJECT_NAME
spec:
  selector:
    app: $PROJECT_NAME
  ports:
  - protocol: TCP
    port: 80
    targetPort: 3000
  type: ClusterIP
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: $PROJECT_NAME-ingress
  namespace: $PROJECT_NAME
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - host: $PROJECT_NAME.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: $PROJECT_NAME-service
            port:
              number: 80
EOF

# Create GitHub Actions workflow
log "🔄 Creating GitHub Actions workflow..."
cat > .github/workflows/ci-cd.yml << EOF
name: CI/CD Pipeline

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: \${{ github.repository }}

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Setup Node.js
      uses: actions/setup-node@v4
      with:
        node-version: '18'
        cache: 'npm'
    
    - name: Install dependencies
      run: npm ci
    
    - name: Run linter
      run: npm run lint
    
    - name: Run tests
      run: npm test

  build:
    needs: test
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    
    steps:
    - name: Checkout repository
      uses: actions/checkout@v4
    
    - name: Log in to Container Registry
      uses: docker/login-action@v3
      with:
        registry: \${{ env.REGISTRY }}
        username: \${{ github.actor }}
        password: \${{ secrets.GITHUB_TOKEN }}
    
    - name: Extract metadata
      id: meta
      uses: docker/metadata-action@v5
      with:
        images: \${{ env.REGISTRY }}/\${{ env.IMAGE_NAME }}
        tags: |
          type=ref,event=branch
          type=ref,event=pr
          type=sha,prefix={{branch}}-
    
    - name: Build and push Docker image
      uses: docker/build-push-action@v5
      with:
        context: .
        push: true
        tags: \${{ steps.meta.outputs.tags }}
        labels: \${{ steps.meta.outputs.labels }}

  deploy:
    needs: build
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    
    steps:
    - name: Deploy to production
      run: |
        echo "🚀 Deploying to production..."
        # Add your deployment commands here
EOF

# Create .gitignore
log "📝 Creating .gitignore..."
cat > .gitignore << EOF
# Dependencies
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Environment variables
.env
.env.local
.env.development.local
.env.test.local
.env.production.local

# Logs
logs
*.log
npm-debug.log*
yarn-debug.log*
yarn-error.log*
lerna-debug.log*

# Runtime data
pids
*.pid
*.seed
*.pid.lock

# Coverage directory used by tools like istanbul
coverage/
*.lcov

# Build output
dist/
build/

# OS generated files
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db

# Editor directories and files
.vscode/
.idea/
*.swp
*.swo

# Docker
.docker/

# Kubernetes
kubeconfig
EOF

# Create README.md
log "📖 Creating README.md..."
cat > README.md << EOF
# $PROJECT_NAME

A modern application built with DevOps best practices.

## 🚀 Quick Start

### Using Docker Compose
\`\`\`bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down
\`\`\`

### Local Development
\`\`\`bash
# Install dependencies
npm install

# Start development server
npm run dev

# Run tests
npm test
\`\`\`

## 🏗️ Architecture

- **Backend**: Node.js with Express
- **Database**: PostgreSQL
- **Cache**: Redis
- **Container**: Docker
- **Orchestration**: Kubernetes
- **CI/CD**: GitHub Actions

## 📁 Project Structure

\`\`\`
$PROJECT_NAME/
├── src/                 # Application source code
├── tests/              # Test files
├── k8s/                # Kubernetes manifests
├── docker/             # Docker configurations
├── scripts/            # Utility scripts
├── .github/workflows/  # CI/CD pipelines
└── docs/               # Documentation
\`\`\`

## 🔧 Development

### Environment Variables
Copy \`.env.example\` to \`.env\` and configure:

\`\`\`bash
NODE_ENV=development
PORT=3000
DATABASE_URL=postgresql://postgres:password123@localhost:5432/$PROJECT_NAME
REDIS_URL=redis://localhost:6379
\`\`\`

### Available Scripts

- \`npm start\` - Start production server
- \`npm run dev\` - Start development server with hot reload
- \`npm test\` - Run tests
- \`npm run build\` - Build Docker image
- \`npm run deploy\` - Deploy to Kubernetes

## 🚀 Deployment

### Kubernetes
\`\`\`bash
# Apply all manifests
kubectl apply -f k8s/

# Check deployment status
kubectl get pods -n $PROJECT_NAME
\`\`\`

### Docker
\`\`\`bash
# Build image
docker build -t $PROJECT_NAME .

# Run container
docker run -p 3000:3000 $PROJECT_NAME
\`\`\`

## 📊 Monitoring

- Health check: \`GET /health\`
- Status endpoint: \`GET /api/status\`

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## 📄 License

MIT License - see LICENSE file for details.
EOF

# Create .env.example
log "🔐 Creating .env.example..."
cat > .env.example << EOF
# Application
NODE_ENV=development
PORT=3000

# Database
DATABASE_URL=postgresql://postgres:password123@localhost:5432/$PROJECT_NAME

# Redis
REDIS_URL=redis://localhost:6379

# JWT
JWT_SECRET=your-secret-key-here

# External APIs
API_KEY=your-api-key-here
EOF

# Initialize npm
log "📦 Installing npm dependencies..."
npm install

# Make scripts executable
chmod +x scripts/*.sh 2>/dev/null || true

# Initial git commit
log "📝 Creating initial commit..."
git add .
git commit -m "🎉 Initial commit: Project created with DevOps Toolkit

- ✅ Express.js application setup
- 🐳 Docker and Docker Compose configuration
- ☸️ Kubernetes manifests
- 🔄 GitHub Actions CI/CD pipeline
- 📝 Comprehensive documentation
- 🔧 Development tools and scripts"

log "✅ Project $PROJECT_NAME created successfully!"
log ""
log "🎉 Next steps:"
log "1. cd $PROJECT_NAME"
log "2. Copy .env.example to .env and configure"
log "3. Run 'docker-compose up -d' to start services"
log "4. Visit http://localhost:3000 to see your app"
log "5. Start coding in the src/ directory"
log ""
log "📖 Documentation: README.md"
log "🐳 Docker: docker-compose up -d"
log "☸️ Kubernetes: kubectl apply -f k8s/"
log "🔄 CI/CD: Push to GitHub to trigger workflows" 