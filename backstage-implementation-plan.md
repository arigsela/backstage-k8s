# Backstage Implementation Plan - Docker Compose Deployment

## Table of Contents
1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Architecture](#architecture)
4. [Implementation Progress](#implementation-progress)
5. [Completed Phases](#completed-phases)
   - [Phase 1: Initial Setup](#phase-1-initial-setup) ✅
   - [Phase 2: Database Configuration](#phase-2-database-configuration) ✅
   - [Phase 3: Docker Compose Deployment](#phase-3-docker-compose-deployment) ✅
6. [Remaining Phases](#remaining-phases)
   - [Phase 4: POC Plugin Installation](#phase-4-poc-plugin-installation)
   - [Phase 5: Production Configuration](#phase-5-production-configuration)
7. [Configuration Files](#configuration-files)
8. [Deployment Steps](#deployment-steps)
9. [Maintenance and Operations](#maintenance-and-operations)

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

## Implementation Progress

### Current Status
- **Project Name**: asela-apps (created via `npx @backstage/create-app`)
- **Environment**: Development and Docker Compose deployment ready
- **Database**: PostgreSQL configured and running
- **Access URL**: http://localhost:7007
- **Branch**: adding-gh-authentication

### Completed Items
- ✅ Backstage application scaffolded and configured
- ✅ PostgreSQL database integration (replaced SQLite)
- ✅ Docker multi-stage build configured
- ✅ Docker Compose deployment working
- ✅ Environment variables configured with secure defaults
- ✅ Health checks implemented
- ✅ Application accessible via Docker containers

### Pending Items (Phase 4 - POC Focus)
- ⏳ Kubernetes plugin installation and configuration
- ⏳ Kubernetes Ingestor setup for auto-discovery
- ⏳ Crossplane plugin integration
- ⏳ GitHub Actions plugin setup
- ⏳ Test entity creation with all plugins
- ⏳ Production Kubernetes cluster configuration
- ⏳ RBAC setup for Kubernetes access

## Completed Phases

## Phase 1: Initial Setup ✅

### Step 1: Create Project Directory
```bash
mkdir backstage-k8s
cd backstage-k8s
```

### Step 2: Create Backstage App
**Actual command used:**
```bash
npx @backstage/create-app@latest
# App name provided: asela-apps
cd asela-apps
```

### Step 3: Verify Installation
```bash
# Start development server
yarn start

# Verify app is running at http://localhost:3000 (frontend)
# Backend runs at http://localhost:7007
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

## Phase 2: Database Configuration ✅

### Step 1: Install PostgreSQL Dependencies
```bash
cd asela-apps
yarn --cwd packages/backend add pg
```

### Step 2: Create Docker Compose for Local Development
Created `docker-compose.dev.yml`:
```yaml
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    container_name: backstage-postgres-dev
    restart: unless-stopped
    environment:
      POSTGRES_USER: backstage
      POSTGRES_PASSWORD: backstage
      POSTGRES_DB: backstage
    ports:
      - "5432:5432"
    volumes:
      - postgres_dev_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U backstage"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  postgres_dev_data:
    driver: local
```

### Step 3: Update Local Configuration
Updated `app-config.local.yaml`:
```yaml
backend:
  database:
    client: pg
    connection:
      host: localhost
      port: 5432
      user: backstage
      password: backstage
      database: backstage
```

### Step 4: Create Production Configuration
Created `app-config.production.yaml`:

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
```

### Step 2: Install PostgreSQL Dependencies
```bash
yarn --cwd packages/backend add pg
```

### Step 5: Test Database Connection
```bash
# Start PostgreSQL
docker-compose -f docker-compose.dev.yml up -d

# Verify Backstage connects to PostgreSQL
yarn start
# Check logs for PostgreSQL connection confirmation
```

## Phase 3: Docker Compose Deployment ✅

### Step 1: Create Multi-Stage Dockerfile
Created `asela-apps/Dockerfile`:

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
RUN yarn build:backend

# Stage 2: Runtime
FROM node:20-bookworm-slim

# Install runtime dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    libsqlite3-dev python3 ca-certificates && \
    rm -rf /var/lib/apt/lists/* && \
    yarn config set python /usr/bin/python3

# Install mkdocs-techdocs-core for TechDocs
RUN pip3 install --break-system-packages mkdocs-techdocs-core==1.1.7

# Create non-root user
RUN groupadd -r backstage && useradd -r -g backstage -m backstage

# Set working directory
WORKDIR /app

# Change ownership
RUN chown -R backstage:backstage /app

# Switch to non-root user
USER backstage

# Set production environment
ENV NODE_ENV=production

# Copy built application from build stage
COPY --from=build --chown=backstage:backstage /app/yarn.lock /app/package.json /app/.yarnrc.yml ./
COPY --from=build --chown=backstage:backstage /app/.yarn/releases /app/.yarn/releases
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
Created `docker-compose.yml` in root directory:

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
      context: ./asela-apps
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
      
      # Backend configuration
      BACKEND_SECRET: ${BACKEND_SECRET}
      
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

# Backend Configuration
BACKEND_SECRET=your-backend-secret-key

# GitHub Integration (optional - currently disabled)
# GITHUB_TOKEN=your-github-personal-access-token

# Node.js Configuration
NODE_ENV=production
```

### Step 4: Deploy with Docker Compose
```bash
# Copy .env.example to .env
cp .env.example .env

# Generate secure backend secret
openssl rand -hex 32
# Update BACKEND_SECRET in .env with generated value

# Generate secure PostgreSQL password
openssl rand -base64 20 | tr -d "=+/" | cut -c1-16
# Update POSTGRES_PASSWORD in .env with generated value

# Build and start services
docker-compose build
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f backstage

# Access application
# Open http://localhost:7007 in browser
```

### Step 5: Create Nginx Configuration (Optional)
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
backstage-k8s/
├── asela-apps/
│   ├── app-config.yaml
│   ├── app-config.local.yaml (gitignored)
│   ├── app-config.production.yaml
│   ├── Dockerfile
│   ├── docker-compose.dev.yml
│   ├── packages/
│   │   ├── app/
│   │   └── backend/
│   └── ...
├── docker-compose.yml
├── .env (gitignored)
├── .env.example
├── backstage-implementation-plan.md
├── README.md
├── nginx.conf (optional)
├── scripts/
│   ├── backup.sh
│   └── restore.sh
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

## Remaining Phases

## Phase 4: POC Plugin Installation

This phase focuses on installing and configuring essential plugins for a Kubernetes-focused POC: Kubernetes, Kubernetes Ingestor, Crossplane, and GitHub Actions.

### Prerequisites
- Backstage application running with PostgreSQL
- Access to a Kubernetes cluster (local or remote)
- GitHub account and repository access
- Node.js 20.x and Yarn installed

### Step 1: Install Kubernetes Plugin

#### Frontend Installation
```bash
# Install the Kubernetes frontend plugin
cd asela-apps
yarn --cwd packages/app add @backstage/plugin-kubernetes
```

#### Update Entity Page
Edit `packages/app/src/components/catalog/EntityPage.tsx`:
```typescript
import { EntityKubernetesContent } from '@backstage/plugin-kubernetes';

// Add to the service entity page
const serviceEntityPage = (
  <EntityLayout>
    {/* ... existing routes ... */}
    <EntityLayout.Route path="/kubernetes" title="Kubernetes">
      <EntityKubernetesContent />
    </EntityLayout.Route>
  </EntityLayout>
);
```

#### Backend Installation
```bash
# Install the Kubernetes backend plugin
yarn --cwd packages/backend add @backstage/plugin-kubernetes-backend
```

#### Configure Kubernetes Clusters

**Local Development Configuration**

For local development, use the 'local' cluster locator:
```yaml
# app-config.local.yaml
kubernetes:
  serviceLocatorMethod: 'singleTenant'
  clusterLocatorMethods:
    - 'local'  # Uses kubectl proxy on port 8001
```

Start kubectl proxy:
```bash
kubectl proxy --port=8001
```

**Production - In-Cluster Configuration**

When Backstage is deployed in the same cluster it monitors:
```yaml
# app-config.production.yaml
kubernetes:
  serviceLocatorMethod: 'singleTenant'
  clusterLocatorMethods:
    - 'config'
  clusters:
    - url: https://kubernetes.default.svc
      name: local-cluster
      authProvider: 'serviceAccount'
      # Uses the pod's service account token automatically mounted at:
      # /var/run/secrets/kubernetes.io/serviceaccount/token
```

The URL `https://kubernetes.default.svc` is the standard in-cluster API server address. Kubernetes automatically:
- Provides this DNS name for the API server
- Mounts service account credentials in the pod
- Handles TLS certificates

#### Add Kubernetes Annotations to Entities
Update your `catalog-info.yaml` files:
```yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: my-service
  annotations:
    # Option 1: Simple entity matching
    'backstage.io/kubernetes-id': my-service
    
    # Option 2: Label selector
    # 'backstage.io/kubernetes-label-selector': 'app=my-app,component=backend'
```

### Step 2: Install Kubernetes Ingestor Plugin

The Kubernetes Ingestor automatically creates catalog entities from Kubernetes resources.

#### Backend Installation
```bash
# Install the ingestor plugin (from TeraSky)
yarn --cwd packages/backend add @terasky/backstage-plugin-kubernetes-ingestor
```

#### Configure the Ingestor
Add to `packages/backend/src/index.ts`:
```typescript
import { KubernetesIngestorProvider } from '@terasky/backstage-plugin-kubernetes-ingestor';

// In your backend initialization
backend.add(
  KubernetesIngestorProvider.fromConfig(env.config, {
    logger: env.logger,
    discovery: env.discovery,
    tokenManager: env.tokenManager,
  })
);
```

Update `app-config.yaml`:
```yaml
catalog:
  providers:
    kubernetesIngestor:
      # Auto-ingest standard workloads
      ingestWorkloads: true
      # Auto-ingest Crossplane claims
      ingestCrossplaneClaims: true
      # Custom resource types to ingest
      customResources:
        - group: apps.example.com
          version: v1
          kind: CustomApp
```

### Step 3: Install Crossplane Plugin

#### Frontend Installation
```bash
# Install Crossplane resources plugin
yarn --cwd packages/app add @terasky/backstage-plugin-crossplane-resources-frontend
```

#### Backend Permissions Installation (Optional)
```bash
# If using permissions framework
yarn --cwd packages/backend add @terasky/backstage-plugin-crossplane-permissions
```

#### Update Entity Page for Crossplane
Edit `packages/app/src/components/catalog/EntityPage.tsx`:
```typescript
import { 
  CrossplaneAllResourcesTable, 
  CrossplaneResourceGraph, 
  isCrossplaneAvailable,
  CrossplaneOverviewCard 
} from '@terasky/backstage-plugin-crossplane-resources-frontend';

// Add to overview page
const overviewContent = (
  <Grid container spacing={3}>
    {/* ... existing cards ... */}
    <EntitySwitch>
      <EntitySwitch.Case if={isCrossplaneAvailable}>
        <Grid item md={6}>
          <CrossplaneOverviewCard />
        </Grid>
      </EntitySwitch.Case>
    </EntitySwitch>
  </Grid>
);

// Add Crossplane tab
const serviceEntityPage = (
  <EntityLayout>
    {/* ... existing routes ... */}
    <EntityLayout.Route path="/crossplane" title="Crossplane">
      <CrossplaneAllResourcesTable />
    </EntityLayout.Route>
    <EntityLayout.Route path="/crossplane-graph" title="Resource Graph">
      <CrossplaneResourceGraph />
    </EntityLayout.Route>
  </EntityLayout>
);
```

### Step 4: Install GitHub Actions Plugin

#### Frontend Installation
```bash
# Install the community GitHub Actions plugin
yarn --cwd packages/app add @backstage-community/plugin-github-actions
```

#### Backend Configuration (if needed)
```bash
# If not already installed for GitHub auth
yarn --cwd packages/backend add @backstage/plugin-auth-backend-module-github-provider
```

#### Update Entity Page for GitHub Actions
Edit `packages/app/src/components/catalog/EntityPage.tsx`:
```typescript
import { 
  EntityGithubActionsContent,
  isGithubActionsAvailable,
  EntityRecentGithubActionsRunsCard
} from '@backstage-community/plugin-github-actions';

// Add to overview page
const cicdCard = (
  <EntitySwitch>
    <EntitySwitch.Case if={isGithubActionsAvailable}>
      <Grid item sm={6}>
        <EntityRecentGithubActionsRunsCard limit={4} variant="gridItem" />
      </Grid>
    </EntitySwitch.Case>
  </EntitySwitch>
);

// Add CI/CD tab
const serviceEntityPage = (
  <EntityLayout>
    {/* ... existing routes ... */}
    <EntityLayout.Route path="/ci-cd" title="CI/CD">
      <EntityGithubActionsContent />
    </EntityLayout.Route>
  </EntityLayout>
);
```

#### Configure GitHub Integration
Update `app-config.yaml`:
```yaml
integrations:
  github:
    - host: github.com
      token: ${GITHUB_TOKEN}  # Personal Access Token with repo and actions:read permissions

# For GitHub OAuth (optional)
auth:
  providers:
    github:
      development:
        clientId: ${AUTH_GITHUB_CLIENT_ID}
        clientSecret: ${AUTH_GITHUB_CLIENT_SECRET}
```

#### Add GitHub Annotations to Entities
Update your `catalog-info.yaml` files:
```yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: my-service
  annotations:
    github.com/project-slug: 'myorg/my-service-repo'
```

### Step 5: Test Plugin Integration

#### 1. Restart Backstage
```bash
# Stop current instance
# Then rebuild and start
yarn install
yarn dev
```

#### 2. Create Test Entities
Create `examples/test-component.yaml`:
```yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: test-kubernetes-app
  description: Test component with all plugins enabled
  annotations:
    backstage.io/kubernetes-id: test-app
    backstage.io/kubernetes-label-selector: 'app=test-app'
    github.com/project-slug: 'myorg/test-app'
spec:
  type: service
  lifecycle: production
  owner: platform-team
```

#### 3. Register the Component
1. Navigate to http://localhost:3000/catalog-import
2. Enter the URL or paste the YAML content
3. Import the component

#### 4. Verify Plugin Functionality
- Check the Kubernetes tab shows cluster resources
- Verify GitHub Actions tab displays workflow runs
- Confirm Crossplane resources are visible (if you have Crossplane installed)

### Troubleshooting

#### Kubernetes Plugin Issues
```bash
# Quick start for kubectl proxy
kubectl proxy --port=8001 &  # Run in background
# Or in foreground to see logs
kubectl proxy --port=8001

# Check current context
kubectl config current-context

# Test proxy is working
curl http://localhost:8001/api/v1/namespaces

# Verify cluster access
kubectl cluster-info

# Check service account permissions
kubectl auth can-i list pods --all-namespaces

# If using specific kubeconfig file
export KUBECONFIG=/path/to/your/kubeconfig
kubectl proxy --port=8001
```

#### GitHub Actions Issues
- Ensure GitHub token has `repo` and `actions:read` permissions
- Verify the `github.com/project-slug` annotation matches your repository

#### Crossplane Plugin Issues
- Ensure Kubernetes Ingestor is properly configured
- Verify Crossplane is installed in your cluster
- Check that Crossplane claims exist in the cluster

### Production Deployment Requirements

#### RBAC Configuration for In-Cluster Access
When running Backstage in Kubernetes, create the necessary RBAC permissions:

```yaml
# kubernetes-rbac.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: backstage
  namespace: backstage
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: backstage-kubernetes-reader
rules:
  # Core resources
  - apiGroups: [""]
    resources: ["pods", "services", "configmaps", "secrets", "limitranges", "resourcequotas"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["apps"]
    resources: ["deployments", "replicasets", "statefulsets", "daemonsets"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["batch"]
    resources: ["jobs", "cronjobs"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["networking.k8s.io"]
    resources: ["ingresses"]
    verbs: ["get", "list", "watch"]
  # For metrics
  - apiGroups: ["metrics.k8s.io"]
    resources: ["pods"]
    verbs: ["get", "list"]
  # For Crossplane resources (if using Crossplane plugin)
  - apiGroups: ["*"]
    resources: ["*"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: backstage-kubernetes-reader
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: backstage-kubernetes-reader
subjects:
  - kind: ServiceAccount
    name: backstage
    namespace: backstage
```

Apply this before deploying Backstage:
```bash
kubectl create namespace backstage
kubectl apply -f kubernetes-rbac.yaml
```

Then update your Docker Compose deployment to use this service account when deploying to Kubernetes.

### Next Steps
Once plugins are working:
1. Deploy Backstage to Kubernetes with proper service account
2. Test in-cluster API access
3. Create templates for Crossplane resources
4. Integrate GitHub Actions workflows with Backstage
5. Add monitoring and alerting for deployed resources

## Phase 5: Production Configuration

### Production Readiness
1. SSL/TLS certificate setup
2. Domain configuration  
3. Production authentication setup
4. Monitoring and observability
5. Backup automation
6. Security hardening
7. High availability configuration

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

This implementation plan provides a complete guide for deploying Backstage using Docker Compose. 

### Completed Setup
- ✅ Multi-stage Docker builds for optimized images
- ✅ PostgreSQL database with persistent storage
- ✅ Docker Compose deployment working
- ✅ Health checks implemented
- ✅ Environment variable configuration
- ✅ Basic security measures

### Next Steps (POC Focus)
- ⏳ Install Kubernetes plugin for cluster visibility
- ⏳ Configure Kubernetes Ingestor for auto-discovery
- ⏳ Set up Crossplane plugin for infrastructure management
- ⏳ Enable GitHub Actions plugin for CI/CD visibility
- ⏳ Create test entities demonstrating all plugin capabilities
- ⏳ Configure production Kubernetes cluster access
- ⏳ Implement proper RBAC for secure cluster access

### Current Access
- **Application URL**: http://localhost:7007
- **Database**: PostgreSQL on port 5432
- **Container Names**: backstage-app, backstage-postgres

For additional customization and plugin development, refer to the official Backstage documentation at https://backstage.io/docs.