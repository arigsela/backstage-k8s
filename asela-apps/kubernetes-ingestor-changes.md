# Kubernetes Ingestor Configuration Changes

## Summary
This branch contains the necessary changes to enable the TeraSky kubernetes-ingestor plugin to automatically discover and catalog Kubernetes resources in Backstage.

## Key Changes Made

### 1. app-config.yaml
- **Moved kubernetes-ingestor configuration to root level** (was incorrectly placed under `catalog.providers`)
- **Fixed authentication configuration** for kubectl proxy:
  - Changed from `authProvider: 'localKubectlProxy'` to `authProvider: 'serviceAccount'`
  - Added `serviceAccountToken: 'unused-token-for-proxy'` (dummy token for kubectl proxy)
  - Added `skipTLSVerify: true`
- **Set `onlyAnnotated: false`** to discover all Kubernetes resources (not just annotated ones)
- **Fixed frequency format** from object to number (60 seconds)
- **Added complete ingestor configuration** with mappings, components, and Crossplane settings

### 2. test-k8s-deployment-corrected.yaml
- Created a test deployment with proper TeraSky annotations for testing
- Includes namespace, deployment, service, and configmap resources
- All resources have the required `terasky.backstage.io/*` annotations

## Configuration Details

The kubernetes-ingestor is now configured to:
- Run every 60 seconds (instead of default 10 minutes)
- Ingest all workloads (deployments, services, etc.) 
- Discover resources in all namespaces except system namespaces
- Support Crossplane claim ingestion
- Use namespace-based naming and system mapping

## Results
After these changes, the kubernetes-ingestor successfully discovered and created 38 components in the Backstage catalog from the Kubernetes cluster.

## Testing
To test the configuration:
1. Ensure kubectl proxy is running: `kubectl proxy`
2. Start Backstage: `./start-with-kubectl-proxy.sh`
3. Navigate to http://localhost:3000/catalog
4. You should see Kubernetes resources appearing as catalog entities

## Next Steps
- Review the changes
- Consider setting `onlyAnnotated: true` if you only want to discover annotated resources
- Adjust the frequency and timeout values based on your cluster size
- Add custom resource definitions if needed