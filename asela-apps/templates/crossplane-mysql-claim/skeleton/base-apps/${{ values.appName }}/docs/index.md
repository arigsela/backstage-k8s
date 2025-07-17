# ${{ values.appName }} MySQL Database

## Overview

This documentation covers the **${{ values.databaseName }}** MySQL database instance provisioned for the **${{ values.appName }}** application in the **${{ values.namespace }}** namespace.

!!! info "Database Information" - **Database Name**: `${{ values.databaseName }}` - **Environment**: `${{ values.environment }}` - **Owner**: ${{ values.owner | replace("group:default/", "") | replace("user:default/", "") }}
    - **System**: ${{ values.system | replace("system:default/", "") | replace("system:local/", "") }}
    - **Namespace**: `${{ values.namespace }}`

## Quick Start

### Connection Details

```bash
# Database Host
mysql.${{ values.namespace }}.svc.cluster.local:3306

# Database Name
${{ values.databaseName }}

# Username
${{ values.username }}
```

### Getting the Password

The database password is stored securely in Vault:

```bash
# Using Vault CLI
vault kv get secret/${{ values.appName }}/DB_PASSWORD

# Or retrieve from Kubernetes secret
kubectl get secret ${{ values.appName }}-secret -n ${{ values.namespace }} -o jsonpath='{.data.DB_PASSWORD}' | base64 -d
```

## User Privileges

This database user has the following privileges:

{% for privilege in values.privileges %}

- **{{ privilege }}**: {{
    "Read data from tables" if privilege == "SELECT" else
    "Insert new data into tables" if privilege == "INSERT" else
    "Modify existing data in tables" if privilege == "UPDATE" else
    "Remove data from tables" if privilege == "DELETE" else
    "Create new tables and databases" if privilege == "CREATE" else
    "Remove tables and databases" if privilege == "DROP" else
    "Create and remove indexes" if privilege == "INDEX" else
    "Modify table structure" if privilege == "ALTER" else
    privilege + " operations"
  }}
  {% endfor %}

## Quick Links

| Resource                 | Link                                                                                                                                                                                                                                                                                               | Description               |
| ------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------- |
| 🔐 **Vault Secret**      | [${{ values.vaultUrl }}/ui/vault/secrets/secret/show/${{ values.appName }}/DB_PASSWORD](${{ values.vaultUrl }}/ui/vault/secrets/secret/show/${{ values.appName }}/DB_PASSWORD)                                                                                                                     | Database password storage |
| 📊 **Grafana Dashboard** | [${{ values.grafanaUrl }}/d/mysql-overview/mysql-database-overview?var-database=${{ values.databaseName }}&var-namespace=${{ values.namespace }}](${{ values.grafanaUrl }}/d/mysql-overview/mysql-database-overview?var-database=${{ values.databaseName }}&var-namespace=${{ values.namespace }}) | Database monitoring       |
| 🗄️ **phpMyAdmin**        | [${{ values.phpMyAdminUrl }}/index.php?db=${{ values.databaseName }}&server=${{ values.namespace }}-mysql](${{ values.phpMyAdminUrl }}/index.php?db=${{ values.databaseName }}&server=${{ values.namespace }}-mysql)                                                                               | Database administration   |
| 💬 **Support Channel**   | [Slack Channel](https://slack.com/app_redirect?channel=${{ values.slackChannel }})                                                                                                                                                                                                                 | Get help and support      |

## Next Steps

1. **[Connect to the Database →](connection.md)** - Detailed connection instructions
2. **[Set up Authentication →](authentication.md)** - Configure secure access
3. **[Operations Guide →](operations.md)** - Backup, restore, and maintenance
4. **[Troubleshooting →](troubleshooting.md)** - Common issues and solutions

## Architecture

This MySQL database is provisioned using **Crossplane** with the following components:

- **MySQLDatabase**: Custom resource managing the database lifecycle
- **External Secrets**: Automatic password management via Vault
- **ArgoCD Application**: GitOps-based deployment and management
- **Kubernetes Service**: Internal cluster access endpoint

!!! tip "Best Practices" - Always use connection pooling in your applications - Monitor database performance regularly via Grafana - Keep backups up to date using the automated backup system - Follow security guidelines when handling database credentials

---

**Generated on**: {{ timestamp }}  
**Template Version**: {{ templateVersion | default("1.0.0") }}
