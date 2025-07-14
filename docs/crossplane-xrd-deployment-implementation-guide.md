# Crossplane XRD Deployment via Backstage - Implementation Guide

## Quick Start

This guide provides step-by-step instructions to implement Crossplane XRD deployment through Backstage, integrated with your existing GitOps workflow.

## Prerequisites

- [ ] Backstage instance running (currently on Docker Compose)
- [ ] Access to `arigsela/kubernetes` GitOps repository
- [ ] Vault configured with database passwords
- [ ] External Secrets Operator installed in cluster
- [ ] GitHub token with write access to GitOps repo

## Implementation Steps

### Step 1: Create the Scaffolder Template

1. Create directory structure:
```bash
cd asela-apps
mkdir -p templates/crossplane-mysql-database/content
```

2. Create the main template file:
```bash
cat > templates/crossplane-mysql-database/template.yaml << 'EOF'
apiVersion: scaffolder.backstage.io/v1beta3
kind: Template
metadata:
  name: crossplane-mysql-database
  title: Crossplane MySQL Database
  description: Create a MySQL database using Crossplane XRD with Vault secret management
  tags:
    - crossplane
    - database
    - mysql
    - gitops
spec:
  owner: platform-team
  type: resource
  parameters:
    - title: Database Configuration
      required:
        - name
        - namespace
        - databaseName
        - username
      properties:
        name:
          title: Resource Name
          type: string
          description: Name for the MySQLDatabase resource
          pattern: '^[a-z0-9]([-a-z0-9]*[a-z0-9])?$'
        namespace:
          title: Namespace
          type: string
          description: Kubernetes namespace for the database
        databaseName:
          title: Database Name
          type: string
          description: Actual database name in MySQL
        username:
          title: Database Username
          type: string
          description: Username for database access
        userNamespace:
          title: User Namespace
          type: string
          description: Namespace where user credentials will be created
          default: "${{ parameters.namespace }}-backend"
    - title: Vault Configuration
      required:
        - vaultSecretPath
      properties:
        vaultSecretPath:
          title: Vault Secret Path
          type: string
          description: Path in Vault where the database password is stored
          default: "secret/data/mysql/${{ parameters.name }}"
        vaultSecretKey:
          title: Vault Secret Key
          type: string
          description: Key in Vault secret containing the password
          default: "password"
        privileges:
          title: Database Privileges
          type: array
          description: List of privileges for the user
          default:
            - SELECT
            - INSERT
            - UPDATE
            - DELETE
          items:
            type: string
            enum:
              - SELECT
              - INSERT
              - UPDATE
              - DELETE
              - CREATE
              - DROP
              - INDEX
              - ALTER

  steps:
    - id: fetch
      name: Fetch Base
      action: fetch:template
      input:
        url: ./content
        values:
          name: ${{ parameters.name }}
          namespace: ${{ parameters.namespace }}
          databaseName: ${{ parameters.databaseName }}
          username: ${{ parameters.username }}
          userNamespace: ${{ parameters.userNamespace }}
          vaultSecretPath: ${{ parameters.vaultSecretPath }}
          vaultSecretKey: ${{ parameters.vaultSecretKey }}
          privileges: ${{ parameters.privileges }}

    - id: publish
      name: Publish to GitHub
      action: publish:github:pull-request
      input:
        repoUrl: github.com?owner=arigsela&repo=kubernetes
        title: "Deploy MySQLDatabase: ${{ parameters.name }}"
        description: |
          This PR creates a new MySQLDatabase resource via Crossplane XRD.
          
          **Resource Details:**
          - Name: `${{ parameters.name }}`
          - Namespace: `${{ parameters.namespace }}`
          - Database: `${{ parameters.databaseName }}`
          - User: `${{ parameters.username }}`
          - Vault Path: `${{ parameters.vaultSecretPath }}`
          
          **Files Created:**
          - ArgoCD Application: `base-apps/${{ parameters.namespace }}-${{ parameters.name }}.yaml`
          - Secret Store: `base-apps/${{ parameters.namespace }}-${{ parameters.name }}/secret_stores.yaml`
          - External Secret: `base-apps/${{ parameters.namespace }}-${{ parameters.name }}/external_secrets.yaml`
          - MySQL Database: `base-apps/${{ parameters.namespace }}-${{ parameters.name }}/mysql-database.yaml`
        branchName: mysql-db-${{ parameters.namespace }}-${{ parameters.name }}
        targetPath: ./

    - id: register
      name: Register in Catalog
      action: catalog:register
      input:
        repoContentsUrl: ${{ steps.publish.output.repoContentsUrl }}
        catalogInfoPath: '/base-apps/${{ parameters.namespace }}-${{ parameters.name }}/catalog-info.yaml'

  output:
    links:
      - title: Pull Request
        url: ${{ steps.publish.output.remoteUrl }}
      - title: Open in catalog
        icon: catalog
        entityRef: ${{ steps.register.output.entityRef }}
EOF
```

3. Create the ArgoCD application template:
```bash
cat > templates/crossplane-mysql-database/content/base-apps/${{ values.namespace }}-${{ values.name }}.yaml << 'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ${{ values.namespace }}-${{ values.name }}
  namespace: argo-cd
  labels:
    app.kubernetes.io/managed-by: backstage
spec:
  project: default
  source:
    repoURL: https://github.com/arigsela/kubernetes
    targetRevision: main
    path: base-apps/${{ values.namespace }}-${{ values.name }}
  destination:
    server: https://kubernetes.default.svc
    namespace: ${{ values.namespace }}
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF
```

4. Create the resources directory templates:
```bash
# Secret Store
cat > templates/crossplane-mysql-database/content/base-apps/${{ values.namespace }}-${{ values.name }}/secret_stores.yaml << 'EOF'
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-backend
  namespace: ${{ values.namespace }}
spec:
  provider:
    vault:
      server: "http://vault.vault.svc.cluster.local:8200"
      path: "secret"
      version: "v2"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "external-secrets"
EOF

# External Secret
cat > templates/crossplane-mysql-database/content/base-apps/${{ values.namespace }}-${{ values.name }}/external_secrets.yaml << 'EOF'
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: ${{ values.name }}-secret
  namespace: ${{ values.namespace }}
  labels:
    app.kubernetes.io/name: ${{ values.name }}
    app.kubernetes.io/managed-by: backstage
spec:
  refreshInterval: "1h"
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: ${{ values.name }}-secret
    creationPolicy: Owner
  data:
    - secretKey: DB_PASSWORD
      remoteRef:
        key: ${{ values.vaultSecretPath }}
        property: ${{ values.vaultSecretKey }}
EOF

# MySQL Database XRD
cat > templates/crossplane-mysql-database/content/base-apps/${{ values.namespace }}-${{ values.name }}/mysql-database.yaml << 'EOF'
apiVersion: platform.io/v1alpha1
kind: MySQLDatabase
metadata:
  name: ${{ values.name }}
  namespace: ${{ values.namespace }}
  labels:
    app.kubernetes.io/name: ${{ values.name }}
    app.kubernetes.io/managed-by: backstage
spec:
  parameters:
    databaseName: ${{ values.databaseName }}
    username: ${{ values.username }}
    userNamespace: ${{ values.userNamespace }}
    databaseNamespace: ${{ values.namespace }}
    privileges:
      {{- range $privilege := values.privileges }}
      - "${{ $privilege }}"
      {{- end }}
    passwordSecretRef:
      name: ${{ values.name }}-secret
      key: DB_PASSWORD
      namespace: ${{ values.namespace }}
  writeConnectionSecretToRef:
    name: ${{ values.name }}-connection
EOF

# Catalog Info
cat > templates/crossplane-mysql-database/content/base-apps/${{ values.namespace }}-${{ values.name }}/catalog-info.yaml << 'EOF'
apiVersion: backstage.io/v1alpha1
kind: Resource
metadata:
  name: ${{ values.name }}
  description: MySQL Database provisioned via Crossplane
  annotations:
    backstage.io/kubernetes-id: ${{ values.name }}
    backstage.io/kubernetes-namespace: ${{ values.namespace }}
    argocd/app-name: ${{ values.namespace }}-${{ values.name }}
spec:
  type: database
  owner: platform-team
  lifecycle: production
  system: crossplane-resources
  dependsOn:
    - resource:default/crossplane-provider-mysql
EOF
```

### Step 2: Configure Backstage

1. Update `app-config.yaml`:
```yaml
# Add to existing configuration
scaffolder:
  defaultAuthor:
    name: Backstage Scaffolder
    email: backstage@example.com
  defaultCommitMessage: "feat: Deploy MySQLDatabase ${{ values.name }} via Backstage"

integrations:
  github:
    - host: github.com
      token: ${GITHUB_TOKEN}
      # This token needs write access to arigsela/kubernetes repository

catalog:
  import:
    entityFilename: catalog-info.yaml
    pullRequestBranchName: backstage-catalog-import-${timestamp}
  rules:
    - allow: [Component, System, API, Resource, Location, Template]
  locations:
    # Add the new template
    - type: file
      target: ../../templates/crossplane-mysql-database/template.yaml
      rules:
        - allow: [Template]
```

2. Set the GitHub token in your `.env`:
```bash
echo "GITHUB_TOKEN=your_github_token_here" >> .env
```

### Step 3: Prepare Vault

Before using the template, ensure Vault has the password:

```bash
# Example: Create password in Vault
vault kv put secret/mysql/test-app-db password=supersecretpassword
```

### Step 4: Test the Template

1. Restart Backstage to load the new template:
```bash
docker-compose restart backstage
```

2. Navigate to http://localhost:7007/create
3. You should see "Crossplane MySQL Database" template
4. Fill in the form:
   - Resource Name: `test-app-db`
   - Namespace: `test-app`
   - Database Name: `testapp_db`
   - Username: `testapp_user`
   - Vault Secret Path: `secret/data/mysql/test-app-db`

5. Submit the form and verify:
   - A PR is created in `arigsela/kubernetes`
   - The PR contains all required files
   - Files follow the correct structure

### Step 5: Deploy First Database

1. Review and merge the PR created by Backstage
2. ArgoCD will automatically:
   - Create the namespace
   - Deploy the SecretStore
   - Create the ExternalSecret
   - Deploy the MySQLDatabase XRD
3. Monitor in ArgoCD UI
4. Verify in Backstage catalog

## Troubleshooting

### Common Issues

1. **PR Creation Fails**
   - Check GitHub token permissions
   - Verify token has write access to `arigsela/kubernetes`
   - Check Backstage logs: `docker-compose logs backstage`

2. **External Secret Not Working**
   - Verify Vault path exists: `vault kv get secret/mysql/<name>`
   - Check External Secrets Operator logs
   - Ensure SecretStore has proper authentication

3. **Template Not Appearing**
   - Verify template file syntax
   - Check Backstage logs for template loading errors
   - Ensure template location is in `app-config.yaml`

4. **ArgoCD Not Syncing**
   - Check ArgoCD application status
   - Verify repository access
   - Check for manifest validation errors

## Next Steps

1. **Add More Templates**:
   - PostgreSQL Database
   - Redis Instance
   - S3 Bucket

2. **Enhance Existing Template**:
   - Add database size options
   - Include backup configuration
   - Add monitoring setup

3. **Improve Workflow**:
   - Add automated testing for PRs
   - Implement cost estimation
   - Add approval workflows

## Appendix: Manual Testing

To test without Backstage, create files manually:

```bash
# Create test structure
mkdir -p test-deployment/base-apps/test-app-test-db

# Create ArgoCD app
cat > test-deployment/base-apps/test-app-test-db.yaml << 'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: test-app-test-db
  namespace: argo-cd
spec:
  project: default
  source:
    repoURL: https://github.com/arigsela/kubernetes
    targetRevision: main
    path: base-apps/test-app-test-db
  destination:
    server: https://kubernetes.default.svc
    namespace: test-app
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF

# Copy other files and test
```