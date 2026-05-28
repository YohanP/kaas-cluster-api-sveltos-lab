#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -euo pipefail

# --- Variables ---
SVELTOS_VERSION="v1.10.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "--- 2. Installing Sveltos ${SVELTOS_VERSION} and Base Policies ---"

# --- 1. Install Sveltos ${SVELTOS_VERSION} in Centralized Mode ---
echo "Deploying Sveltos ${SVELTOS_VERSION} with agents in management cluster..."
# We allow this command to fail partially because of missing ServiceMonitor CRDs
kubectl apply -f https://raw.githubusercontent.com/projectsveltos/sveltos/${SVELTOS_VERSION}/manifest/agents_in_mgmt_cluster_manifest.yaml || {
    echo "Warning: Some resources failed to apply (likely ServiceMonitors). Continuing..."
}

# --- 2. Wait for Sveltos CRDs to be established (CRITICAL) ---
echo "Waiting for Sveltos CRDs to be established..."
# This ensures the API server recognizes ClusterProfile before we apply our policies
kubectl wait --for=condition=Established crd/clusterprofiles.config.projectsveltos.io --timeout=60s

# --- 3. Wait for Sveltos Controllers ---
echo "Waiting for Sveltos manager to be ready..."
kubectl wait deployment/addon-controller \
  --for=condition=Available \
  -n projectsveltos \
  --timeout=300s

# Short sleep to allow the API server to catch up
sleep 5

# --- 4. Apply Base Policies (Cilium and Goldpinger) ---
echo "Applying base policies for Cilium and Goldpinger..."
kubectl apply -f "${SCRIPT_DIR}/../policies/cilium.yaml"
kubectl apply -f "${SCRIPT_DIR}/../policies/goldpinger.yaml"

echo "Sveltos ${SVELTOS_VERSION} has been installed and configured successfully."
echo ""
echo "Next step: Deploy the workload cluster."
