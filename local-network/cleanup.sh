#!/bin/bash

set -e

echo "Cleaning up local OP Reth network data..."

# Stop all services
docker compose down -v

# Remove logs
echo "Removing logs..."
rm -rf logs/

# Recreate logs directory
mkdir -p logs/{ec-1,ec-2,beacon-1,beacon-2}

echo "Cleanup completed! All data volumes and logs have been removed."
