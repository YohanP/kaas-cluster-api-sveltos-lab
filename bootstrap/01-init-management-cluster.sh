#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -euo pipefail

# --- Variables ---
# Name of the k3d management cluster
MANAGEMENT_CLUSTER_NAME="capi-management"
# Port to expose the Kubernetes API on the host
KUBE_API_PORT="6443"
# Port mapping for potential ingress or services (e.g., Sveltos UI, Grafana)
EXTRA_PORT_MAPPING="8082:80@loadbalancer"

echo "Starting bootstrap of the CAPI Management Cluster..."

# --- Pre-requisites: Docker Network for CAPD ---
if ! docker network inspect kind >/dev/null 2>&1; then
    echo "Creating Docker network 'kind' for Cluster API..."
    docker network create kind
fi

# --- 1. Create the k3d management cluster ---
if k3d cluster list "${MANAGEMENT_CLUSTER_NAME}" >/dev/null 2>&1; then
    echo "1. Cluster ${MANAGEMENT_CLUSTER_NAME} already exists. Skipping creation."
else
    echo "1. Creating k3d cluster '${MANAGEMENT_CLUSTER_NAME}'"
    k3d cluster create "${MANAGEMENT_CLUSTER_NAME}" \
        --api-port "${KUBE_API_PORT}" \
        -p "${EXTRA_PORT_MAPPING}" \
        -v /var/run/docker.sock:/var/run/docker.sock \
        --wait
    echo "k3d cluster created."
fi

# --- 2. Initialize Cluster API ---
# `clusterctl init` is the standard command to install CAPI components.
# It turns a regular Kubernetes cluster into a management cluster.
# The --infrastructure docker flag tells it to install the Docker provider (CAPD),
# allowing us to create and manage workload clusters as Docker containers.
echo "2. Initializing Cluster API with the Docker infrastructure provider (CAPD)..."
clusterctl init --infrastructure docker

# --- 3. Connect Management Cluster to the 'kind' network ---
# This step is crucial for the management cluster to communicate with 
# the workload clusters created by CAPD on the 'kind' Docker network.
echo "3. Connecting the management cluster to the 'kind' network..."
docker network connect kind "k3d-${MANAGEMENT_CLUSTER_NAME}-server-0"

echo "Bootstrap complete!"
echo "Your CAPI management cluster is ready."
echo ""
echo "To interact with it, ensure your KUBECONFIG is set:"
# Automatically fix the 0.0.0.0/127.0.0.1 TLS issue
k3d kubeconfig get ${MANAGEMENT_CLUSTER_NAME} > capi-management.kubeconfig
sed -i 's/0.0.0.0/127.0.0.1/g' capi-management.kubeconfig
echo "export KUBECONFIG=$(pwd)/capi-management.kubeconfig"
echo ""
echo "You can check the installed providers with:"
echo "kubectl get providers -A"
echo ""
echo "Next step: Install Sveltos."
