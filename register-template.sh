#!/bin/bash

# Register the Crossplane MySQL Database template in Backstage catalog

echo "Registering Crossplane MySQL Database template..."

# First, we need to create a temporary catalog-info.yaml that references our template
cat > /tmp/template-catalog-info.yaml << 'EOF'
apiVersion: backstage.io/v1alpha1
kind: Location
metadata:
  name: crossplane-mysql-template
  description: Location for Crossplane MySQL Database template
spec:
  type: url
  target: https://github.com/arigsela/backstage-k8s/blob/main/asela-apps/templates/crossplane-mysql-database/template.yaml
EOF

# Register the location via API
curl -X POST http://localhost:7007/api/catalog/locations \
  -H "Content-Type: application/json" \
  -d '{
    "type": "url",
    "target": "https://github.com/arigsela/backstage-k8s/blob/main/asela-apps/templates/crossplane-mysql-database/template.yaml"
  }'

echo ""
echo "Template registration initiated. Check the Backstage UI in a few moments."
echo "If the template doesn't appear, check the catalog at: http://localhost:7007/catalog"