# Connection Guide

## Database Connection Details

### Basic Connection Information

| Parameter    | Value                                             |
| ------------ | ------------------------------------------------- |
| **Host**     | `mysql.${{ values.namespace }}.svc.cluster.local` |
| **Port**     | `3306`                                            |
| **Database** | `${{ values.databaseName }}`                      |
| **Username** | `${{ values.username }}`                          |
| **SSL**      | Required                                          |

### Getting the Password

!!! warning "Security Notice"
Never hardcode database passwords in your application code. Always retrieve them from secure storage.

#### Option 1: From Kubernetes Secret

```bash
# Get password from Kubernetes secret
kubectl get secret ${{ values.appName }}-secret \
  -n ${{ values.namespace }} \
  -o jsonpath='{.data.DB_PASSWORD}' | base64 -d
```

#### Option 2: From Vault

```bash
# Using Vault CLI
vault kv get -field=DB_PASSWORD secret/${{ values.appName }}

# Using Vault UI
# Navigate to: ${{ values.vaultUrl }}/ui/vault/secrets/secret/show/${{ values.appName }}/DB_PASSWORD
```

## Application Integration

### Environment Variables

Configure your application with these environment variables:

```bash
# Database connection
DB_HOST=mysql.${{ values.namespace }}.svc.cluster.local
DB_PORT=3306
DB_NAME=${{ values.databaseName }}
DB_USER=${{ values.username }}
DB_PASSWORD_SECRET_NAME=${{ values.appName }}-secret
DB_PASSWORD_SECRET_KEY=DB_PASSWORD
```

### Connection Strings

#### Python (PyMySQL)

```python
import pymysql
import os
from kubernetes import client, config

def get_db_password():
    """Retrieve password from Kubernetes secret"""
    config.load_incluster_config()  # or load_kube_config() for local dev
    v1 = client.CoreV1Api()
    secret = v1.read_namespaced_secret(
        name="${{ values.appName }}-secret",
        namespace="${{ values.namespace }}"
    )
    return base64.b64decode(secret.data['DB_PASSWORD']).decode('utf-8')

# Database connection
connection = pymysql.connect(
    host='mysql.${{ values.namespace }}.svc.cluster.local',
    port=3306,
    user='${{ values.username }}',
    password=get_db_password(),
    database='${{ values.databaseName }}',
    charset='utf8mb4',
    ssl={'ssl_disabled': False},
    autocommit=True
)
```

#### Java (Spring Boot)

```yaml
# application.yml
spring:
  datasource:
    url: jdbc:mysql://mysql.${{ values.namespace }}.svc.cluster.local:3306/${{ values.databaseName }}?useSSL=true&requireSSL=true
    username: ${{ values.username }}
    password: ${DB_PASSWORD} # Injected from secret
    driver-class-name: com.mysql.cj.jdbc.Driver
  jpa:
    database-platform: org.hibernate.dialect.MySQL8Dialect
    hibernate:
      ddl-auto: validate
```

#### Node.js (mysql2)

```javascript
const mysql = require('mysql2/promise');
const k8s = require('@kubernetes/client-node');

async function getDbPassword() {
  const kc = new k8s.KubeConfig();
  kc.loadFromCluster(); // or loadFromDefault() for local dev

  const k8sApi = kc.makeApiClient(k8s.CoreV1Api);
  const secret = await k8sApi.readNamespacedSecret(
    '${{ values.appName }}-secret',
    '${{ values.namespace }}',
  );

  return Buffer.from(secret.body.data.DB_PASSWORD, 'base64').toString();
}

async function createConnection() {
  const password = await getDbPassword();

  return mysql.createConnection({
    host: 'mysql.${{ values.namespace }}.svc.cluster.local',
    port: 3306,
    user: '${{ values.username }}',
    password: password,
    database: '${{ values.databaseName }}',
    ssl: { rejectUnauthorized: true },
  });
}
```

#### Go

```go
package main

import (
    "context"
    "database/sql"
    "fmt"

    _ "github.com/go-sql-driver/mysql"
    metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
    "k8s.io/client-go/kubernetes"
    "k8s.io/client-go/rest"
)

func getDbPassword() (string, error) {
    config, err := rest.InClusterConfig()
    if err != nil {
        return "", err
    }

    clientset, err := kubernetes.NewForConfig(config)
    if err != nil {
        return "", err
    }

    secret, err := clientset.CoreV1().Secrets("${{ values.namespace }}").Get(
        context.TODO(),
        "${{ values.appName }}-secret",
        metav1.GetOptions{},
    )
    if err != nil {
        return "", err
    }

    return string(secret.Data["DB_PASSWORD"]), nil
}

func main() {
    password, err := getDbPassword()
    if err != nil {
        panic(err)
    }

    dsn := fmt.Sprintf("%s:%s@tcp(mysql.${{ values.namespace }}.svc.cluster.local:3306)/${{ values.databaseName }}?tls=true",
        "${{ values.username }}", password)

    db, err := sql.Open("mysql", dsn)
    if err != nil {
        panic(err)
    }
    defer db.Close()
}
```

## Connection Pooling

!!! tip "Performance Recommendation"
Always use connection pooling for better performance and resource management.

### Recommended Pool Settings

| Parameter               | Development | Production |
| ----------------------- | ----------- | ---------- |
| **Max Connections**     | 5           | 20-50      |
| **Idle Connections**    | 2           | 5-10       |
| **Connection Lifetime** | 5 minutes   | 15 minutes |
| **Connection Timeout**  | 30 seconds  | 10 seconds |

## Network Access

### From Within Kubernetes

Applications running in the same Kubernetes cluster can connect using the internal service name:

```
mysql.${{ values.namespace }}.svc.cluster.local:3306
```

### From Outside Kubernetes

!!! warning "Security"
Direct external access to the database is not recommended for security reasons. Use application APIs instead.

If external access is absolutely necessary, contact the platform team via the [support channel](https://slack.com/app_redirect?channel=${{ values.slackChannel }}).

## Troubleshooting

### Common Connection Issues

1. **Connection Timeout**

   - Check if your application is in the correct namespace
   - Verify network policies allow database access

2. **Authentication Failed**

   - Ensure you're using the correct username: `${{ values.username }}`
   - Verify the password from the Kubernetes secret

3. **SSL/TLS Errors**
   - Ensure SSL is enabled in your connection string
   - Check that your MySQL client supports TLS 1.2+

For more troubleshooting information, see the [Troubleshooting Guide](troubleshooting.md).

## Next Steps

- [Authentication Setup →](authentication.md)
- [Operations Guide →](operations.md)
- [Security Best Practices →](security.md)
