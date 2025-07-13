# Backstage Implementation Plan - Docker Compose Deployment

## Table of Contents
1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Architecture](#architecture)
4. [Phase 1: Initial Setup](#phase-1-initial-setup)
5. [Phase 2: Database Configuration](#phase-2-database-configuration)
6. [Phase 3: Authentication Setup](#phase-3-authentication-setup)
7. [Phase 4: Docker Compose Deployment](#phase-4-docker-compose-deployment)
8. [Configuration Files](#configuration-files)
9. [Deployment Steps](#deployment-steps)
10. [Maintenance and Operations](#maintenance-and-operations)

## Overview

This document provides a comprehensive guide for implementing Backstage using Docker Compose. Backstage is an open-source developer portal that unifies all your infrastructure tooling, services, and documentation to create a streamlined development environment.

### Key Benefits
- **Centralized Developer Portal**: Single place for all development resources
- **Service Catalog**: Track all microservices, libraries, data pipelines, etc.
- **Software Templates**: Standardize new project creation
- **TechDocs**: Integrated documentation platform
- **Plugin Ecosystem**: Extend functionality with community or custom plugins

## Prerequisites

### System Requirements
- **Operating System**: Linux, macOS, or Windows with WSL2
- **Docker**: Version 20.10 or later
- **Docker Compose**: Version 2.0 or later
- **Node.js**: Active LTS version (20.x recommended)
- **Yarn**: Version 4.x (Classic Yarn 1.x also supported)
- **Git**: For version control
- **Memory**: Minimum 4GB RAM
- **Storage**: At least 10GB free space

### Required Accounts (for full functionality)
- GitHub account (for authentication and integrations)
- Domain name (optional, for production deployment)
- SSL certificates (optional, for HTTPS)

## Architecture

### Component Overview
```
┌─────────────────┐     ┌─────────────────┐
│                 │     │                 │
│  Load Balancer  │────▶│   Nginx Proxy   │
│  (Optional)     │     │   (Optional)    │
│                 │     │                 │
└─────────────────┘     └────────┬────────┘
                                 │
                                 ▼
                        ┌─────────────────┐
                        │                 │
                        │   Backstage     │
                        │   Application   │
                        │   (Port 7007)   │
                        │                 │
                        └────────┬────────┘
                                 │
                                 ▼
                        ┌─────────────────┐
                        │                 │
                        │   PostgreSQL    │
                        │   Database      │
                        │   (Port 5432)   │
                        │                 │
                        └─────────────────┘
```

### Container Services
1. **backstage**: Main application container
2. **postgres**: PostgreSQL database
3. **nginx** (optional): Reverse proxy for SSL termination
4. **oauth2-proxy** (optional): Authentication proxy

## Phase 1: Initial Setup

### Step 1: Create Project Directory
```bash
mkdir backstage-deployment
cd backstage-deployment
```

### Step 2: Create Backstage App
```bash
npx @backstage/create-app@latest --name backstage
cd backstage
```

### Step 3: Initial Configuration
Create base configuration file `app-config.yaml`:

```yaml
app:
  title: My Company Backstage
  baseUrl: http://localhost:3000

organization:
  name: My Company

backend:
  # Used for enabling authentication, secret is shared by all backend plugins
  # See https://backstage.io/docs/auth/service-to-service-auth for
  # information on the format
  auth:
    keys:
      - secret: ${BACKEND_SECRET}
  baseUrl: http://localhost:7007
  listen:
    port: 7007
    host: 0.0.0.0
  cors:
    origin: http://localhost:3000
    methods: [GET, HEAD, PATCH, POST, PUT, DELETE]
    credentials: true
  database:
    client: better-sqlite3
    connection: ':memory:'

integrations:
  github:
    - host: github.com
      token: ${GITHUB_TOKEN}

proxy:
  '/test':
    target: 'https://example.com'
    changeOrigin: true

techdocs:
  builder: 'local'
  generator:
    runIn: 'local'
  publisher:
    type: 'local'

catalog:
  import:
    entityFilename: catalog-info.yaml
    pullRequestBranchName: backstage-integration
  rules:
    - allow: [Component, System, API, Resource, Location]
  locations:
    - type: file
      target: ../../examples/entities.yaml
    - type: file
      target: ../../examples/template/template.yaml
      rules:
        - allow: [Template]
    - type: file
      target: ../../examples/org.yaml
      rules:
        - allow: [User, Group]
```

## Phase 2: Database Configuration

### Step 1: Create Production Configuration
Create `app-config.production.yaml`:

```yaml
app:
  baseUrl: ${APP_BASE_URL}

backend:
  baseUrl: ${BACKEND_BASE_URL}
  listen:
    port: 7007
    host: 0.0.0.0
  database:
    client: pg
    connection:
      host: ${POSTGRES_HOST}
      port: ${POSTGRES_PORT}
      user: ${POSTGRES_USER}
      password: ${POSTGRES_PASSWORD}
      database: ${POSTGRES_DB}
      ssl:
        require: ${POSTGRES_SSL_REQUIRED}
        rejectUnauthorized: false

auth:
  providers:
    github:
      development:
        clientId: ${AUTH_GITHUB_CLIENT_ID}
        clientSecret: ${AUTH_GITHUB_CLIENT_SECRET}
```

### Step 2: Install PostgreSQL Dependencies
```bash
yarn --cwd packages/backend add pg
```

## Phase 3: Authentication Setup

### Step 1: Configure GitHub OAuth App
1. Go to GitHub Settings > Developer settings > OAuth Apps
2. Create new OAuth App with:
   - Homepage URL: `http://localhost:3000`
   - Authorization callback URL: `http://localhost:7007/api/auth/github/handler/frame`

### Step 2: Update Frontend Authentication
Edit `packages/app/src/App.tsx`:

```tsx
import { githubAuthApiRef } from '@backstage/core-plugin-api';
import { SignInPage } from '@backstage/core-components';

const app = createApp({
  apis,
  bindRoutes({ bind }) {
    /* existing bindings */
  },
  components: {
    SignInPage: props => (
      <SignInPage
        {...props}
        auto
        provider={{
          id: 'github-auth-provider',
          title: 'GitHub',
          message: 'Sign in using GitHub',
          apiRef: githubAuthApiRef,
        }}
      />
    ),
  },
});
```

### Step 3: Configure Sign-in Resolvers
Update `app-config.production.yaml`:

```yaml
auth:
  environment: production
  providers:
    github:
      production:
        clientId: ${AUTH_GITHUB_CLIENT_ID}
        clientSecret: ${AUTH_GITHUB_CLIENT_SECRET}
        signIn:
          resolvers:
            - resolver: usernameMatchingUserEntityName
```

## Phase 4: Docker Compose Deployment

### Step 1: Create Multi-Stage Dockerfile
Create `Dockerfile` in the project root:

```dockerfile
# Stage 1: Build
FROM node:20-bookworm-slim AS build

# Install dependencies for building
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    python3 g++ build-essential git && \
    rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /app

# Copy package files
COPY package.json yarn.lock ./
COPY packages/backend/package.json packages/backend/
COPY packages/app/package.json packages/app/

# Copy yarn workspace files
COPY .yarn ./.yarn
COPY .yarnrc.yml ./

# Install dependencies
RUN yarn install --immutable

# Copy application source
COPY . .

# Build TypeScript
RUN yarn tsc

# Build backend
RUN yarn build:backend --config app-config.yaml --config app-config.production.yaml

# Stage 2: Runtime
FROM node:20-bookworm-slim

# Install runtime dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    libsqlite3-dev python3 ca-certificates && \
    rm -rf /var/lib/apt/lists/* && \
    yarn config set python /usr/bin/python3

# Install mkdocs-techdocs-core for TechDocs
RUN pip3 install mkdocs-techdocs-core==1.1.7

# Create non-root user
RUN groupadd -r backstage && useradd -r -g backstage backstage

# Set working directory
WORKDIR /app

# Change ownership
RUN chown -R backstage:backstage /app

# Switch to non-root user
USER backstage

# Set production environment
ENV NODE_ENV=production

# Copy built application from build stage
COPY --from=build --chown=backstage:backstage /app/yarn.lock /app/package.json /app/.yarn /app/.yarnrc.yml ./
COPY --from=build --chown=backstage:backstage /app/packages/backend/dist/skeleton.tar.gz ./

# Extract skeleton
RUN tar xzf skeleton.tar.gz && rm skeleton.tar.gz

# Install production dependencies
RUN yarn workspaces focus --all --production

# Copy bundle and configs
COPY --from=build --chown=backstage:backstage /app/packages/backend/dist/bundle.tar.gz ./
COPY --from=build --chown=backstage:backstage /app/app-config*.yaml ./

# Extract bundle
RUN tar xzf bundle.tar.gz && rm bundle.tar.gz

# Expose port
EXPOSE 7007

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD node -e "require('http').get('http://localhost:7007/healthcheck', (r) => {if(r.statusCode !== 200) throw new Error()})"

# Start the application
CMD ["node", "packages/backend", "--config", "app-config.yaml", "--config", "app-config.production.yaml"]
```

### Step 2: Create Docker Compose Configuration
Create `docker-compose.yml`:

```yaml
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    container_name: backstage-postgres
    restart: unless-stopped
    environment:
      POSTGRES_USER: ${POSTGRES_USER:-backstage}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-backstage}
      POSTGRES_DB: ${POSTGRES_DB:-backstage}
    ports:
      - "${POSTGRES_PORT:-5432}:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER:-backstage}"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - backstage

  backstage:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: backstage-app
    restart: unless-stopped
    ports:
      - "${BACKSTAGE_PORT:-7007}:7007"
    environment:
      # App configuration
      APP_BASE_URL: ${APP_BASE_URL:-http://localhost:3000}
      BACKEND_BASE_URL: ${BACKEND_BASE_URL:-http://localhost:7007}
      
      # Database configuration
      POSTGRES_HOST: postgres
      POSTGRES_PORT: 5432
      POSTGRES_USER: ${POSTGRES_USER:-backstage}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-backstage}
      POSTGRES_DB: ${POSTGRES_DB:-backstage}
      POSTGRES_SSL_REQUIRED: ${POSTGRES_SSL_REQUIRED:-false}
      
      # Auth configuration
      BACKEND_SECRET: ${BACKEND_SECRET}
      AUTH_GITHUB_CLIENT_ID: ${AUTH_GITHUB_CLIENT_ID}
      AUTH_GITHUB_CLIENT_SECRET: ${AUTH_GITHUB_CLIENT_SECRET}
      
      # GitHub integration
      GITHUB_TOKEN: ${GITHUB_TOKEN}
      
      # Node.js configuration
      NODE_ENV: production
      NODE_OPTIONS: "--max-old-space-size=4096"
    depends_on:
      postgres:
        condition: service_healthy
    networks:
      - backstage
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:7007/healthcheck"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  # Optional: Nginx reverse proxy for SSL termination
  nginx:
    image: nginx:alpine
    container_name: backstage-nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./ssl:/etc/nginx/ssl:ro
    depends_on:
      - backstage
    networks:
      - backstage
    profiles:
      - with-nginx

volumes:
  postgres_data:
    driver: local

networks:
  backstage:
    driver: bridge
```

### Step 3: Create Environment File
Create `.env.example`:

```bash
# PostgreSQL Configuration
POSTGRES_USER=backstage
POSTGRES_PASSWORD=your-secure-password
POSTGRES_DB=backstage
POSTGRES_PORT=5432
POSTGRES_SSL_REQUIRED=false

# Backstage Configuration
BACKSTAGE_PORT=7007
APP_BASE_URL=http://localhost:3000
BACKEND_BASE_URL=http://localhost:7007

# Authentication
BACKEND_SECRET=your-backend-secret-key
AUTH_GITHUB_CLIENT_ID=your-github-client-id
AUTH_GITHUB_CLIENT_SECRET=your-github-client-secret

# GitHub Integration
GITHUB_TOKEN=your-github-personal-access-token

# Node.js Configuration
NODE_ENV=production
```

### Step 4: Create Nginx Configuration (Optional)
Create `nginx.conf`:

```nginx
events {
    worker_connections 1024;
}

http {
    upstream backstage {
        server backstage:7007;
    }

    server {
        listen 80;
        server_name your-domain.com;
        
        # Redirect to HTTPS
        return 301 https://$server_name$request_uri;
    }

    server {
        listen 443 ssl;
        server_name your-domain.com;

        ssl_certificate /etc/nginx/ssl/cert.pem;
        ssl_certificate_key /etc/nginx/ssl/key.pem;

        location / {
            proxy_pass http://backstage;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            # WebSocket support
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
        }
    }
}
```

## Configuration Files

### Directory Structure
```
backstage-deployment/
├── backstage/
│   ├── app-config.yaml
│   ├── app-config.production.yaml
│   ├── Dockerfile
│   ├── packages/
│   │   ├── app/
│   │   └── backend/
│   └── ...
├── docker-compose.yml
├── .env
├── .env.example
├── nginx.conf (optional)
└── ssl/ (optional)
    ├── cert.pem
    └── key.pem
```

### Essential Configuration Updates

#### 1. Catalog Configuration
Add to `app-config.yaml`:

```yaml
catalog:
  import:
    entityFilename: catalog-info.yaml
    pullRequestBranchName: backstage-integration
  rules:
    - allow: [Component, System, API, Resource, Location, User, Group, Template]
  locations:
    # Add your own catalog locations here
    - type: url
      target: https://github.com/your-org/backstage-catalog/blob/main/catalog-info.yaml
```

#### 2. TechDocs Configuration
Add to `app-config.production.yaml`:

```yaml
techdocs:
  builder: 'local'
  generator:
    runIn: 'docker'
  publisher:
    type: 'local'
  # For cloud storage (optional):
  # publisher:
  #   type: 'googleGcs'
  #   googleGcs:
  #     bucketName: 'techdocs-storage'
  #     projectId: 'your-gcp-project'
```

#### 3. Proxy Configuration
Add to `app-config.yaml` for API integrations:

```yaml
proxy:
  '/jenkins':
    target: 'https://jenkins.example.com'
    headers:
      Authorization: 'Bearer ${JENKINS_TOKEN}'
  '/sonarqube':
    target: 'https://sonarqube.example.com'
    headers:
      Authorization: 'Bearer ${SONARQUBE_TOKEN}'
```

## Deployment Steps

### Step 1: Prepare Environment
```bash
# Copy example environment file
cp .env.example .env

# Edit .env with your values
nano .env

# Generate a secure backend secret
openssl rand -hex 32
```

### Step 2: Build and Start Services
```bash
# Build images
docker-compose build

# Start services
docker-compose up -d

# Check logs
docker-compose logs -f

# Verify services are running
docker-compose ps
```

### Step 3: Initial Setup
1. Access Backstage at http://localhost:7007
2. Sign in with GitHub
3. Import your first component:
   - Click "Create Component"
   - Choose "Register Existing Component"
   - Enter URL to your `catalog-info.yaml`

### Step 4: Production Deployment
For production deployment with HTTPS:

```bash
# Start with nginx profile
docker-compose --profile with-nginx up -d
```

## Maintenance and Operations

### Backup and Restore

#### Database Backup
```bash
# Backup
docker-compose exec postgres pg_dump -U backstage backstage > backup_$(date +%Y%m%d_%H%M%S).sql

# Restore
docker-compose exec -T postgres psql -U backstage backstage < backup.sql
```

#### Automated Backup Script
Create `backup.sh`:

```bash
#!/bin/bash
BACKUP_DIR="/path/to/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/backstage_backup_$TIMESTAMP.sql"

# Create backup directory if it doesn't exist
mkdir -p $BACKUP_DIR

# Perform backup
docker-compose exec -T postgres pg_dump -U backstage backstage > $BACKUP_FILE

# Compress backup
gzip $BACKUP_FILE

# Remove backups older than 30 days
find $BACKUP_DIR -name "backstage_backup_*.sql.gz" -mtime +30 -delete

echo "Backup completed: ${BACKUP_FILE}.gz"
```

### Monitoring

#### Health Checks
```bash
# Check application health
curl http://localhost:7007/healthcheck

# Check database connection
docker-compose exec backstage node -e "
const pg = require('pg');
const client = new pg.Client({
  host: process.env.POSTGRES_HOST,
  user: process.env.POSTGRES_USER,
  password: process.env.POSTGRES_PASSWORD,
  database: process.env.POSTGRES_DB
});
client.connect().then(() => {
  console.log('Database connection successful');
  client.end();
}).catch(err => {
  console.error('Database connection failed:', err);
  process.exit(1);
});
"
```

#### Logs Management
```bash
# View all logs
docker-compose logs

# View specific service logs
docker-compose logs backstage
docker-compose logs postgres

# Follow logs in real-time
docker-compose logs -f

# Export logs
docker-compose logs > backstage_logs_$(date +%Y%m%d).log
```

### Updates and Upgrades

#### Updating Backstage
```bash
# Stop services
docker-compose down

# Update Backstage
cd backstage
yarn upgrade @backstage/cli@latest
yarn upgrade @backstage/core-app-api@latest
yarn upgrade @backstage/core-components@latest
yarn upgrade @backstage/core-plugin-api@latest

# Rebuild
cd ..
docker-compose build --no-cache

# Start services
docker-compose up -d
```

#### Database Migrations
Backstage handles database migrations automatically on startup. Monitor logs during updates:

```bash
docker-compose logs -f backstage | grep -i migration
```

### Troubleshooting

#### Common Issues and Solutions

1. **Database Connection Failed**
   ```bash
   # Check postgres is running
   docker-compose ps postgres
   
   # Check environment variables
   docker-compose exec backstage env | grep POSTGRES
   
   # Test connection manually
   docker-compose exec backstage apt-get update && apt-get install -y postgresql-client
   docker-compose exec backstage psql -h postgres -U backstage -d backstage
   ```

2. **Authentication Issues**
   ```bash
   # Verify GitHub OAuth settings
   echo "Callback URL should be: ${BACKEND_BASE_URL}/api/auth/github/handler/frame"
   
   # Check backend secret is set
   docker-compose exec backstage node -e "console.log(process.env.BACKEND_SECRET ? 'Secret is set' : 'Secret is missing')"
   ```

3. **Performance Issues**
   ```bash
   # Increase Node.js memory
   # Add to docker-compose.yml environment:
   NODE_OPTIONS: "--max-old-space-size=8192"
   
   # Check resource usage
   docker stats
   ```

### Security Best Practices

1. **Environment Variables**
   - Never commit `.env` files to version control
   - Use strong, unique passwords
   - Rotate secrets regularly

2. **Network Security**
   - Use HTTPS in production
   - Implement proper firewall rules
   - Restrict database access

3. **Updates**
   - Keep Backstage and dependencies updated
   - Monitor security advisories
   - Test updates in staging first

### Scaling Considerations

For high availability:

```yaml
# docker-compose.prod.yml
version: '3.8'

services:
  backstage:
    deploy:
      replicas: 3
      update_config:
        parallelism: 1
        delay: 10s
      restart_policy:
        condition: on-failure
```

## Conclusion

This implementation plan provides a complete guide for deploying Backstage using Docker Compose. The setup includes:

- Multi-stage Docker builds for optimized images
- PostgreSQL database with persistent storage
- GitHub authentication integration
- Health checks and monitoring
- Backup and restore procedures
- Security best practices

For additional customization and plugin development, refer to the official Backstage documentation at https://backstage.io/docs.