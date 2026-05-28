#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -euo pipefail

# Name of the k3d management cluster
MANAGEMENT_CLUSTER_NAME="capi-management"

echo "--- Cleaning up the Cloud Provider Lab ---"

# --- 1. Cleanup Workload Clusters (CAPD) ---
# CAPD creates containers with the label 'io.x-k8s.kind.cluster'.
# We find all such containers and remove them.
echo "1. Identifying and removing any CAPD workload containers..."
CAPD_CONTAINERS=$(docker ps -a -q --filter "label=io.x-k8s.kind.cluster")
if [ -n "$CAPD_CONTAINERS" ]; then
    echo "Removing workload containers..."
    docker rm -f $CAPD_CONTAINERS
    echo "Workload containers removed."
else
    echo "No workload containers found."
fi

# --- 2. Delete k3d management cluster ---
if k3d cluster list "${MANAGEMENT_CLUSTER_NAME}" >/dev/null 2>&1; then
    echo "2. Deleting k3d cluster '${MANAGEMENT_CLUSTER_NAME}'..."
    k3d cluster delete "${MANAGEMENT_CLUSTER_NAME}"
    echo "Management cluster deleted."
else
    echo "Management cluster '${MANAGEMENT_CLUSTER_NAME}' does not exist."
fi

# --- 3. Cleanup Docker Networks ---
if docker network inspect kind >/dev/null 2>&1; then
    echo "3. Removing Docker network 'kind'..."
    docker network rm kind
    echo "Network 'kind' removed."
fi

# --- 4. Cleanup local files and contexts ---
echo "4. Cleaning up local kubeconfig files and contexts..."
rm -f *.kubeconfig
kubectl config delete-context "k3d-${MANAGEMENT_CLUSTER_NAME}" 2>/dev/null || true
kubectl config delete-cluster "k3d-${MANAGEMENT_CLUSTER_NAME}" 2>/dev/null || true
kubectl config delete-user "admin@k3d-${MANAGEMENT_CLUSTER_NAME}" 2>/dev/null || true

echo "Cleanup complete. Your environment is fresh."
