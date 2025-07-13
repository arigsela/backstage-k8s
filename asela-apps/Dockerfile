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
    libsqlite3-dev python3 python3-pip ca-certificates && \
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