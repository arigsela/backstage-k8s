# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a Backstage Docker Compose deployment repository that provides a production-ready setup for running Backstage, an open-source developer portal platform. The repository includes Crossplane integration for infrastructure-as-code workflows and GitOps templates.

## Project Structure

```
backstage-k8s/
├── asela-apps/                      # Main Backstage application
│   ├── packages/
│   │   ├── app/                     # Frontend React application
│   │   └── backend/                 # Backend Node.js API server
│   ├── plugins/                     # Custom Backstage plugins
│   ├── templates/                   # Software templates for scaffolding
│   │   └── crossplane-mysql-database/ # Crossplane MySQL template
│   └── examples/                    # Example entities and configurations
├── docker-compose.yml              # Main Docker Compose configuration
├── docs/                           # Implementation documentation
└── scripts/                        # Database backup/restore scripts
```

## Key Technologies

- **Backstage**: Open-source developer portal (Node.js + React)
- **PostgreSQL**: Database backend
- **Docker Compose**: Container orchestration
- **Crossplane**: Infrastructure provisioning (MySQL databases)
- **ArgoCD/GitOps**: Infrastructure deployment workflows

## Common Development Commands

### Backstage Development (in asela-apps/)
```bash
# Install dependencies
yarn install

# Start development server (frontend + backend)
yarn start

# Build all packages
yarn build:all

# Build backend only
yarn build:backend

# Run tests
yarn test

# Run all tests with coverage
yarn test:all

# Run E2E tests with Playwright
yarn test:e2e

# Lint code
yarn lint

# Lint all files
yarn lint:all

# Type checking
yarn tsc

# Fix linting issues
yarn fix

# Format code
yarn prettier:check
```

### Docker Compose Operations
```bash
# Start all services (PostgreSQL + Backstage)
docker-compose up -d

# Start with nginx reverse proxy
docker-compose --profile with-nginx up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down

# Rebuild Backstage image
docker-compose build backstage
```

### Database Operations
```bash
# Backup database
docker-compose exec postgres pg_dump -U backstage backstage > backup.sql

# Restore database
docker-compose exec -T postgres psql -U backstage backstage < backup.sql

# Or use the provided scripts
./scripts/backup.sh
./scripts/restore.sh
```

## Architecture Notes

### Backstage Application Structure
- **Frontend (app)**: React SPA with Material-UI components, serves on port 3000 in dev
- **Backend**: Express.js API server with plugin architecture, serves on port 7007
- **Workspace**: Yarn workspaces for monorepo management with shared dependencies

### Container Architecture
- **Production build**: Multi-stage Docker build combining frontend and backend
- **Development**: Uses `yarn start` which runs both frontend and backend with hot reload
- **Database**: PostgreSQL 15 with persistent volumes and health checks

### Template System
- **Software Templates**: Located in `asela-apps/templates/` for scaffolding new projects
- **Crossplane Integration**: Templates generate Kubernetes resources for infrastructure provisioning
- **GitOps Workflow**: Templates create PRs to GitOps repositories for ArgoCD/Flux deployment

### Authentication & Integration
- **GitHub OAuth**: Primary authentication method
- **GitHub Integration**: Repository discovery and code integration
- **Environment Variables**: Configuration via `.env` file (not in git)

## Development Workflow

1. **Local Development**: Use `yarn start` in `asela-apps/` for hot reload development
2. **Testing**: Run `yarn test` for unit tests, `yarn test:e2e` for Playwright E2E tests
3. **Docker Testing**: Use `docker-compose up -d` to test full stack with PostgreSQL
4. **Production Testing**: Use nginx profile to test reverse proxy setup

## Important Configuration Files

- `asela-apps/package.json`: Main workspace configuration and scripts
- `asela-apps/app-config.yaml`: Backstage application configuration
- `asela-apps/app-config.local.yaml`: Local development overrides
- `asela-apps/app-config.production.yaml`: Production configuration
- `docker-compose.yml`: Container orchestration with PostgreSQL and optional nginx
- `asela-apps/playwright.config.ts`: E2E test configuration

## Plugin Development

- Custom plugins go in `asela-apps/plugins/`
- Follow Backstage plugin development patterns
- Use `yarn new` to scaffold new plugins
- Plugins are automatically discovered via workspace configuration

## Template Development

- Software templates are in `asela-apps/templates/`
- Templates use Cookiecutter/Jinja2 syntax for variable substitution
- Test templates using the "Create Component" flow in the UI
- Register templates via `register-template.sh` script

## Crossplane Integration

- MySQL database provisioning via Crossplane XRDs
- Templates generate Kubernetes manifests in GitOps repositories
- ArgoCD/Flux handles actual infrastructure deployment
- External Secrets integration for database credentials