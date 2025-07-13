# Backstage Docker Compose Deployment

This repository contains a production-ready Docker Compose setup for deploying Backstage, an open-source developer portal platform.

## Quick Start

1. **Clone the repository**
   ```bash
   git clone <your-repo-url>
   cd backstage-k8s
   ```

2. **Create Backstage app**
   ```bash
   npx @backstage/create-app@latest --name backstage
   ```

3. **Configure environment**
   ```bash
   cp .env.example .env
   # Edit .env with your values
   ```

4. **Set up GitHub OAuth**
   - Go to [GitHub Settings > Developer settings > OAuth Apps](https://github.com/settings/applications/new)
   - Create new OAuth App with:
     - Homepage URL: `http://localhost:3000`
     - Authorization callback URL: `http://localhost:7007/api/auth/github/handler/frame`
   - Add Client ID and Secret to `.env`

5. **Start services**
   ```bash
   docker-compose up -d
   ```

6. **Access Backstage**
   - Open http://localhost:7007
   - Sign in with GitHub

## Documentation

See the full implementation plan in [backstage-implementation-plan.md](./backstage-implementation-plan.md) for:
- Detailed setup instructions
- Configuration options
- Authentication setup
- Production deployment
- Maintenance procedures
- Troubleshooting guide

## Project Structure

```
backstage-k8s/
├── backstage/                    # Backstage application (created by npx)
├── docker-compose.yml           # Docker Compose configuration
├── .env.example                 # Environment variables template
├── .env                         # Your environment configuration (not in git)
├── .gitignore                   # Git ignore rules
├── nginx.conf                   # Nginx configuration (optional)
├── backstage-implementation-plan.md  # Full documentation
└── README.md                    # This file
```

## Key Features

- **PostgreSQL Database**: Production-ready database setup
- **GitHub Authentication**: Integrated OAuth authentication
- **Health Checks**: Built-in health monitoring
- **Multi-stage Docker Build**: Optimized image size
- **Security**: Non-root user, environment variable management
- **Optional HTTPS**: Nginx reverse proxy configuration

## Commands

### Development
```bash
# Start services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

### Production with HTTPS
```bash
# Start with nginx
docker-compose --profile with-nginx up -d
```

### Backup
```bash
# Backup database
docker-compose exec postgres pg_dump -U backstage backstage > backup.sql

# Restore database
docker-compose exec -T postgres psql -U backstage backstage < backup.sql
```

## Support

For issues and questions:
- Check the [troubleshooting section](./backstage-implementation-plan.md#troubleshooting) in the implementation plan
- Refer to the [official Backstage documentation](https://backstage.io/docs)
- Submit issues to this repository

## License

This deployment configuration is provided under the Apache 2.0 License.