# Backstage with Kubernetes Integration

This is a Backstage application configured with Kubernetes integration, including the TeraSky kubernetes-ingestor plugin for automatic discovery of Kubernetes resources.

## Features

- **Kubernetes Plugin**: View and manage Kubernetes resources directly from Backstage
- **TeraSky Kubernetes Ingestor**: Automatically discover and catalog Kubernetes resources
- **GitHub Actions Integration**: View workflow status and history
- **TechDocs**: Documentation as code support
- **Software Templates**: Create new projects and services from templates

## Prerequisites

- Node.js 18 or 20
- Yarn 4
- Docker (for PostgreSQL and TechDocs)
- Kubernetes cluster access (via kubectl)
- GitHub account (for authentication and GitHub Actions)

## Quick Start

### 1. Install Dependencies

```bash
yarn install
```

### 2. Set Up Environment Variables

Copy the example environment file and configure it:

```bash
cp .env.example .env
```

Edit `.env` and set:

- `GITHUB_TOKEN`: Personal access token for GitHub API access
- `AUTH_GITHUB_CLIENT_ID` and `AUTH_GITHUB_CLIENT_SECRET`: GitHub OAuth app credentials
- PostgreSQL credentials (if using production setup)

### 3. Start the Application

For development with Kubernetes integration:

```bash
./start-with-kubectl-proxy.sh
```

This script:

- Starts `kubectl proxy` on port 8001
- Starts Backstage on port 3000 (frontend) and 7007 (backend)
- Enables Kubernetes plugin features

For standard development:

```bash
yarn start
```

## Kubernetes Integration

### Kubernetes Plugin

The Kubernetes plugin allows you to view Kubernetes resources associated with your Backstage components. Add these annotations to your Kubernetes resources:

```yaml
metadata:
  annotations:
    backstage.io/kubernetes-id: my-app
    backstage.io/kubernetes-namespace: default
    backstage.io/kubernetes-label-selector: 'app=my-app'
```

### TeraSky Kubernetes Ingestor

The kubernetes-ingestor automatically discovers Kubernetes resources and creates Backstage catalog entities from them.

#### Configuration

The ingestor is configured in `app-config.yaml`:

```yaml
kubernetesIngestor:
  mappings:
    namespaceModel: 'namespace' # How to map namespaces
    nameModel: 'name-namespace' # How to name entities
    titleModel: 'name' # How to title entities
    systemModel: 'default' # How to map to systems
  components:
    enabled: true
    taskRunner:
      frequency: 60 # Run every 60 seconds
      timeout: 600 # 10 minutes timeout
    ingestWorkloads: true # Auto-ingest deployments, statefulsets, etc.
    onlyIngestAnnotatedResources: true # Only ingest annotated resources
    excludedNamespaces:
      - kube-system
      - kube-public
      - kube-node-lease
```

#### Annotating Resources for Discovery

To have your Kubernetes resources discovered by the ingestor, add these annotations:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  annotations:
    # Required for discovery
    terasky.backstage.io/add-to-catalog: 'true'

    # Optional metadata
    terasky.backstage.io/system: my-system
    terasky.backstage.io/owner: platform-team
    terasky.backstage.io/component-type: service
    terasky.backstage.io/lifecycle: production
    terasky.backstage.io/source-code-repo-url: https://github.com/myorg/myapp

    # For Kubernetes plugin integration
    backstage.io/kubernetes-id: my-app
    backstage.io/kubernetes-namespace: default
    backstage.io/kubernetes-label-selector: 'app=my-app'
```

#### Testing Kubernetes Discovery

1. Apply the test resources:

```bash
kubectl apply -f test-k8s-deployment-corrected.yaml
```

2. Wait for the ingestor to run (every 60 seconds by default)

3. Check the catalog at http://localhost:3000/catalog

## Configuration

### Main Configuration Files

- `app-config.yaml`: Base configuration
- `app-config.local.yaml`: Local development overrides
- `app-config.production.yaml`: Production configuration

### Database

Development uses SQLite in-memory database by default. For production, configure PostgreSQL in `app-config.production.yaml`.

To use PostgreSQL locally:

```bash
docker-compose up -d
```

## Building for Production

### Build the Application

```bash
yarn build:backend
```

### Docker Build

```bash
docker build . -f packages/backend/Dockerfile -t backstage
```

### Run with Docker Compose

```bash
docker-compose --profile with-app up -d
```

## Development Commands

```bash
# Run tests
yarn test

# Run linting
yarn lint

# Format code
yarn prettier:fix

# Type checking
yarn tsc

# Build all packages
yarn build:all
```

## Troubleshooting

### Kubernetes Connection Issues

1. Ensure kubectl proxy is running:

```bash
kubectl proxy
```

2. Verify cluster access:

```bash
kubectl cluster-info
```

3. Check the Kubernetes configuration in `app-config.yaml`:

```yaml
kubernetes:
  clusterLocatorMethods:
    - type: 'config'
      clusters:
        - url: http://127.0.0.1:8001
          name: local
          authProvider: 'serviceAccount'
          serviceAccountToken: 'unused-token-for-proxy'
```

### Kubernetes Ingestor Not Discovering Resources

1. Check that resources have the required annotation:

```yaml
terasky.backstage.io/add-to-catalog: 'true'
```

2. Verify the namespace is not excluded in configuration

3. Check logs for errors:

```bash
# Look for KubernetesEntityProvider logs
```

4. Ensure `onlyIngestAnnotatedResources` is set correctly:
   - `true`: Only discovers annotated resources
   - `false`: Discovers all resources (not recommended)

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests and linting
5. Submit a pull request

## License

This project is licensed under the Apache 2.0 License.
