#!/bin/bash

# Start yarn in background and capture logs
cd /Users/arisela/git/backstage-k8s/asela-apps

# Create a log file
LOG_FILE="backstage-startup.log"

echo "Starting Backstage and logging to $LOG_FILE..."
echo "This will run for 30 seconds to capture startup logs..."

# Run yarn start in background and redirect output to log file
yarn start > "$LOG_FILE" 2>&1 &
YARN_PID=$!

# Wait for 30 seconds to capture startup logs
sleep 30

# Kill the yarn process
kill $YARN_PID 2>/dev/null

# Show the logs, particularly focusing on kubernetes-related entries
echo "=== Backstage Startup Logs ==="
cat "$LOG_FILE"

echo ""
echo "=== Kubernetes-related logs ==="
grep -i "kubernetes\|ingestor\|k8s" "$LOG_FILE" || echo "No kubernetes-related logs found"

echo ""
echo "=== Error logs ==="
grep -i "error\|warn" "$LOG_FILE" | tail -20 || echo "No errors found"