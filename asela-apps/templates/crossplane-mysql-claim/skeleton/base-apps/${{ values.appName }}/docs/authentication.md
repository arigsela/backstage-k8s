# Authentication Setup

## Overview

This guide covers how to set up secure authentication for your **${{ values.databaseName }}** MySQL database.

## Database User Configuration

### User Details

| Parameter          | Value                    |
| ------------------ | ------------------------ |
| **Username**       | `${{ values.username }}` |
| **Authentication** | MySQL Native Password    |
| **SSL Required**   | Yes                      |

### User Privileges

The database user has been configured with the following privileges:

{% for privilege in values.privileges %}
=== "{{ privilege }}"
{% if privilege == "SELECT" %}
**Read Access**: Query data from tables and views

    ```sql
    -- Examples of SELECT operations
    SELECT * FROM users WHERE active = 1;
    SELECT COUNT(*) FROM orders WHERE date >= '2024-01-01';
    ```
    {% elif privilege == "INSERT" %}
    **Insert Access**: Add new records to tables

    ```sql
    -- Examples of INSERT operations
    INSERT INTO users (name, email) VALUES ('John Doe', 'john@example.com');
    INSERT INTO orders (user_id, product, amount) VALUES (1, 'Product A', 99.99);
    ```
    {% elif privilege == "UPDATE" %}
    **Update Access**: Modify existing records

    ```sql
    -- Examples of UPDATE operations
    UPDATE users SET last_login = NOW() WHERE id = 1;
    UPDATE orders SET status = 'shipped' WHERE id = 123;
    ```
    {% elif privilege == "DELETE" %}
    **Delete Access**: Remove records from tables

    ```sql
    -- Examples of DELETE operations
    DELETE FROM sessions WHERE expires_at < NOW();
    DELETE FROM temp_data WHERE created_at < DATE_SUB(NOW(), INTERVAL 1 DAY);
    ```
    {% elif privilege == "CREATE" %}
    **Create Access**: Create new tables and databases

    ```sql
    -- Examples of CREATE operations
    CREATE TABLE logs (
        id INT AUTO_INCREMENT PRIMARY KEY,
        message TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    ```
    {% elif privilege == "DROP" %}
    **Drop Access**: Remove tables and databases

    ```sql
    -- Examples of DROP operations
    DROP TABLE IF EXISTS temp_table;
    ```
    {% elif privilege == "ALTER" %}
    **Alter Access**: Modify table structure

    ```sql
    -- Examples of ALTER operations
    ALTER TABLE users ADD COLUMN phone VARCHAR(20);
    ALTER TABLE orders MODIFY COLUMN amount DECIMAL(10,2);
    ```
    {% elif privilege == "INDEX" %}
    **Index Access**: Create and manage indexes

    ```sql
    -- Examples of INDEX operations
    CREATE INDEX idx_user_email ON users(email);
    DROP INDEX idx_old_column ON users;
    ```
    {% else %}
    **{{ privilege }}**: Administrative privilege for {{ privilege.lower() }} operations
    {% endif %}

{% endfor %}

## Password Management

### Secure Storage

Database passwords are managed through multiple secure systems:

1. **HashiCorp Vault** (Primary)
2. **Kubernetes Secrets** (Application access)
3. **External Secrets Operator** (Synchronization)

### Password Rotation

!!! warning "Password Rotation"
Passwords are automatically rotated every 90 days. Applications using connection pooling will reconnect automatically.

#### Manual Password Rotation

If you need to rotate the password manually:

```bash
# Generate new password
NEW_PASSWORD=$(openssl rand -base64 32)

# Update in Vault
vault kv put secret/${{ values.appName }} DB_PASSWORD="$NEW_PASSWORD"

# External Secrets will automatically sync to Kubernetes secret
# Monitor the sync:
kubectl get externalsecret ${{ values.appName }}-secret -n ${{ values.namespace }} -w
```

## SSL/TLS Configuration

### Required Settings

All connections to the database **must** use SSL/TLS encryption:

| Setting                      | Value    |
| ---------------------------- | -------- |
| **SSL Mode**                 | Required |
| **TLS Version**              | 1.2+     |
| **Certificate Verification** | Enabled  |

### Connection String Examples

=== "Python (PyMySQL)"

````python
import pymysql

    connection = pymysql.connect(
        host='mysql.${{ values.namespace }}.svc.cluster.local',
        user='${{ values.username }}',
        password=password,
        database='${{ values.databaseName }}',
        ssl={'ssl_disabled': False},  # SSL required
        ssl_verify_cert=True,
        ssl_verify_identity=True
    )
    ```

=== "Java (JDBC)"
```java
String url = "jdbc:mysql://mysql.${{ values.namespace }}.svc.cluster.local:3306/${{ values.databaseName }}" +
"?useSSL=true&requireSSL=true&verifyServerCertificate=true";

    Connection conn = DriverManager.getConnection(url, "${{ values.username }}", password);
    ```

=== "Node.js (mysql2)"
`javascript
    const connection = mysql.createConnection({
        host: 'mysql.${{ values.namespace }}.svc.cluster.local',
        user: '${{ values.username }}',
        password: password,
        database: '${{ values.databaseName }}',
        ssl: {
            rejectUnauthorized: true,
            minVersion: 'TLSv1.2'
        }
    });
    `

=== "Go"
```go
dsn := fmt.Sprintf("%s:%s@tcp(mysql.${{ values.namespace }}.svc.cluster.local:3306)/${{ values.databaseName }}?tls=true&tls-skip-verify=false",
"${{ values.username }}", password)

    db, err := sql.Open("mysql", dsn)
    ```

## Application Authentication

### Service Account Setup

For applications running in Kubernetes, configure a service account with proper RBAC:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ${{ values.appName }}-app
  namespace: ${{ values.namespace }}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: ${{ values.appName }}-secret-reader
  namespace: ${{ values.namespace }}
rules:
  - apiGroups: ['']
    resources: ['secrets']
    resourceNames: ['${{ values.appName }}-secret']
    verbs: ['get', 'list']
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ${{ values.appName }}-secret-reader
  namespace: ${{ values.namespace }}
subjects:
  - kind: ServiceAccount
    name: ${{ values.appName }}-app
    namespace: ${{ values.namespace }}
roleRef:
  kind: Role
  name: ${{ values.appName }}-secret-reader
  apiGroup: rbac.authorization.k8s.io
````

### Environment Variables

Configure your application deployment with these environment variables:

```yaml
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      serviceAccountName: ${{ values.appName }}-app
      containers:
        - name: app
          env:
            - name: DB_HOST
              value: 'mysql.${{ values.namespace }}.svc.cluster.local'
            - name: DB_PORT
              value: '3306'
            - name: DB_NAME
              value: '${{ values.databaseName }}'
            - name: DB_USER
              value: '${{ values.username }}'
            - name: DB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: ${{ values.appName }}-secret
                  key: DB_PASSWORD
```

## Vault Integration

### Accessing Secrets

#### Using Vault CLI

```bash
# Authenticate to Vault
vault auth -method=kubernetes role=${{ values.appName }}-db-reader

# Read the database password
vault kv get -field=DB_PASSWORD secret/${{ values.appName }}
```

#### Using Vault API

```bash
# Get Vault token
VAULT_TOKEN=$(vault write -field=token auth/kubernetes/login \
    role=${{ values.appName }}-db-reader \
    jwt=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token))

# Retrieve password
curl -H "X-Vault-Token: $VAULT_TOKEN" \
    ${{ values.vaultUrl }}/v1/secret/data/${{ values.appName }} | \
    jq -r '.data.data.DB_PASSWORD'
```

### Vault Policy

The following Vault policy is configured for your application:

```hcl
# Policy: ${{ values.appName }}-db-reader
path "secret/data/${{ values.appName }}" {
  capabilities = ["read"]
}

path "secret/metadata/${{ values.appName }}" {
  capabilities = ["read"]
}
```

## Security Best Practices

### Application Level

1. **Never log passwords** in application logs
2. **Use connection pooling** to minimize connection overhead
3. **Implement query timeouts** to prevent long-running queries
4. **Validate all inputs** to prevent SQL injection
5. **Use prepared statements** for all dynamic queries

### Network Level

1. **Network policies** restrict database access to authorized pods only
2. **Service mesh** (if available) provides additional encryption
3. **Egress filtering** prevents unauthorized external connections

### Monitoring

1. **Failed login attempts** are logged and monitored
2. **Unusual query patterns** trigger alerts
3. **Connection metrics** are tracked in Grafana

## Troubleshooting Authentication

### Common Issues

1. **SSL Certificate Errors**

   ```bash
   # Check SSL configuration
   mysql -h mysql.${{ values.namespace }}.svc.cluster.local \
         -u ${{ values.username }} -p \
         --ssl-mode=REQUIRED \
         --ssl-verify-server-cert
   ```

2. **Permission Denied**

   ```bash
   # Verify password from secret
   kubectl get secret ${{ values.appName }}-secret \
     -n ${{ values.namespace }} \
     -o jsonpath='{.data.DB_PASSWORD}' | base64 -d
   ```

3. **Connection Timeout**
   ```bash
   # Test network connectivity
   kubectl run -it --rm debug --image=busybox --restart=Never -- \
     nc -zv mysql.${{ values.namespace }}.svc.cluster.local 3306
   ```

### Getting Help

For authentication issues, contact the platform team:

- **Slack**: [Support Channel](https://slack.com/app_redirect?channel=${{ values.slackChannel }})
- **Email**: platform-team@company.com
- **Emergency**: Page the on-call engineer

## Next Steps

- [Connection Guide →](connection.md)
- [Operations Guide →](operations.md)
- [Security Best Practices →](security.md)
