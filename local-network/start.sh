#!/bin/bash
set -e

echo "Starting local OP Reth network with 2 consensus and 2 execution clients..."

# Create logs directory if it doesn't exist
mkdir -p logs/{ec-1,ec-2,beacon-1,beacon-2}

# Load environment variables if .env exists
if [ -f .env ]; then
    echo "Loading environment variables from .env..."
    source .env
fi

# Start the network
echo "Starting Docker Compose services..."
docker compose up -d

echo "Waiting for services to be healthy..."
sleep 30

# Check service health
echo "Checking service health..."
docker compose ps

echo "Network started successfully!"
echo ""
echo "Access points:"
echo "- op-geth (ec-1) RPC: http://127.0.0.1:18545"
echo "- op-reth (ec-2) RPC: http://127.0.0.1:28545"
echo "- Beacon node 1 API: http://127.0.0.1:19002"
echo "- Beacon node 2 API: http://127.0.0.1:29002"
echo ""
echo "To view logs: docker-compose logs -f [service-name]"
echo "To stop: ./stop.sh"
echo "To test eth_simulateV1: ./scripts/test-eth-simulatev1.sh"
