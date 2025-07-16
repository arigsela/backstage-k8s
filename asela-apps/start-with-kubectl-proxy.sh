#!/bin/bash

# Use Node 20 to match package.json requirements and avoid native module issues
export PATH="/Users/arisela/.nvm/versions/node/v20.19.3/bin:$PATH"
export NODE_OPTIONS="--no-node-snapshot"

# Load environment variables from .env file if it exists
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
    echo "Loaded environment variables from .env"
fi

echo "Using Node version: $(node --version)"
echo ""
echo "Starting kubectl proxy for Kubernetes plugin..."
kubectl proxy --port=8001 &
KUBECTL_PID=$!

echo "kubectl proxy started with PID: $KUBECTL_PID"
echo ""
echo "Starting Backstage development server..."
echo "Access Backstage at http://localhost:3000"
echo ""
echo "To test the plugins:"
echo "1. Navigate to http://localhost:3000/catalog-import"
echo "2. Import the test entity from: file:./examples/test-kubernetes-app.yaml"
echo "3. Update the github.com/project-slug annotation with your actual GitHub repo"
echo ""
echo "Press Ctrl+C to stop both kubectl proxy and Backstage"
echo ""

# Trap Ctrl+C and kill kubectl proxy
trap "echo 'Stopping kubectl proxy...'; kill $KUBECTL_PID; exit" INT

# Start Backstage
yarn start