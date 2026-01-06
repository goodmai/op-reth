#!/bin/bash

set -e

echo "Stopping local OP Reth network..."

# Stop all services
docker compose down

echo "Network stopped successfully!"
echo "Note: Data volumes are preserved. Use ./cleanup.sh to remove all data."
