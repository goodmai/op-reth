# Local Network - eth_simulateV1 Testing Environment

This directory contains a complete local test network for verifying eth_simulateV1 compatibility between op-geth and op-reth execution clients within an Optimism Layer 2 environment.

## Overview

The network consists of:
- **2 Execution Clients**: op-geth (standard) + op-reth (with eth_simulateV1)
- **2 Consensus Clients**: Lighthouse beacon nodes and validator clients
- **Full Block Production**: Real blocks with validator participation
- **Cross-Client Testing**: Verify eth_simulateV1 works identically on both clients

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Local Test Network                            │
│                                                                  │
│  ┌─────────────┐           ┌──────────────┐                     │
│  │ Lighthouse  │           │  Lighthouse  │                     │
│  │ Node + VC   │──────────▶│  Node + VC   │                     │
│  │ (Consensus) │           │ (Consensus)  │                     │
│  └──────┬──────┘           └──────▲───────┘                     │
│         │                          │                             │
│         │                          │                             │
│  ┌──────▼──────┐           ┌──────┴───────┐                     │
│  │  op-geth    │◄─────────▶│   op-reth    │                     │
│  │  (Port 8545)│   P2P     │ (Port 8547)  │                     │
│  │  Standard   │           │ eth_simulateV1│                     │
│  └─────────────┘           └──────────────┘                     │
│         ▲                          ▲                             │
│         │           Testing         │                             │
│         └──────────────────────────┘                             │
│                      Scripts                                     │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Prerequisites

- Docker Engine 24.0+
- Docker Compose 2.20+
- curl (for testing)
- jq (optional, for formatted JSON output)
- 16GB+ RAM recommended
- 50GB+ free disk space

## Quick Start

### 1. Environment Setup

```bash
cd local-network

# Copy environment configuration
cp .env.example .env

# Generate required keys and configuration
./scripts/generate-keys.sh
```

### 2. Start the Network

```bash
# Start all services
docker compose up -d

# Monitor logs
docker compose logs -f
```

### 3. Verify Health

```bash
# Check service status
docker compose ps

# Check logs for errors
docker compose logs --tail=50
```

### 4. Run Tests

```bash
# Run complete eth_simulateV1 test suite
./scripts/test-eth-simulatev1.sh
```

## Service Ports

| Service | Port | Description | URL |
|---------|------|-------------|-----|
| op-geth RPC | 8545 | HTTP JSON-RPC | http://localhost:8545 |
| op-geth WS | 8546 | WebSocket | ws://localhost:8546 |
| op-geth Engine | 18551 | Engine API | - |
| op-geth P2P | 40303 | Peer-to-peer | - |
| op-reth RPC | 8547 | HTTP JSON-RPC (eth_simulateV1) | http://localhost:8547 |
| op-reth WS | 8548 | WebSocket | ws://localhost:8548 |
| op-reth Engine | 28551 | Engine API | - |
| op-reth P2P | 50303 | Peer-to-peer | - |
| Lighthouse-1 API | 5052 | Beacon API | http://localhost:5052 |
| Lighthouse-2 API | 5053 | Beacon API | http://localhost:5053 |
| Validator-1 API | 5062 | Validator API | http://localhost:5062 |
| Validator-2 API | 5063 | Validator API | http://localhost:5063 |

## Testing eth_simulateV1

### Basic Test Suite

Run the comprehensive test suite:

```bash
./scripts/test-eth-simulatev1.sh
```

This tests:
1. ✅ RPC connectivity to both clients
2. ✅ eth_simulateV1 availability on op-reth
3. ✅ eth_simulateV1 availability on op-geth
4. ✅ Simulation result consistency
5. ✅ Block production
6. ✅ Client synchronization

### Manual Testing Examples

#### Test op-geth
```bash
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  --data '{
    "jsonrpc": "2.0",
    "method": "eth_simulateV1",
    "params": [{
      "blockStateCalls": [{
        "blockOverride": {"number": "0x1"},
        "calls": [{
          "from": "0xfe3b557e8fb62b89f4916b721be55ceb828dbd73",
          "gas": "0x5208",
          "gasPrice": "0x3b9aca00"
        }]
      }]
    }],
    "id": 1
  }' | jq
```

#### Test op-reth
```bash
curl -X POST http://localhost:8547 \
  -H "Content-Type: application/json" \
  --data '{
    "jsonrpc": "2.0",
    "method": "eth_simulateV1",
    "params": [{
      "blockStateCalls": [{
        "blockOverride": {"number": "0x1"},
        "calls": [{
          "from": "0xfe3b557e8fb62b89f4916b721be55ceb828dbd73",
          "gas": "0x5208",
          "gasPrice": "0x3b9aca00"
        }]
      }]
    }],
    "id": 1
  }' | jq
```

#### Check Block Number
```bash
# op-geth
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' | jq

# op-reth
curl -X POST http://localhost:8547 \
  -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' | jq
```

## Configuration Details

### Genesis Configuration

The network uses a custom genesis (`configs/genesis.json`) with:
- Chain ID: 1337
- Shanghai enabled at genesis
- Pre-funded test accounts
- Bridge contract predeployed

### JWT Secret

The JWT secret is shared between all clients for authentication:
- Location: `secrets/jwtsecret.hex`
- Format: 64 hex characters
- Automatically generated by `generate-keys.sh`

### Consensus Configuration

Lighthouse runs with minimal configuration:
- 64 validators total (32 per client)
- 12-second slot time
- 8 slots per epoch
- All forks enabled at genesis

## File Structure

```
local-network/
├── configs/
│   ├── genesis.json          # Network genesis configuration
│   └── consensus/            # Lighthouse testnet files
├── scripts/
│   ├── generate-keys.sh      # Generate keys and config
│   └── test-eth-simulatev1.sh # Test eth_simulateV1
├── secrets/
│   ├── jwtsecret.hex         # JWT authentication secret
│   ├── validator-keys-1/     # Lighthouse validator keys
│   └── validator-keys-2/     # Lighthouse validator keys
├── .env.example              # Environment variables template
├── docker-compose.yml        # All services definition
└── README.md                 # This file
```

## Troubleshooting

### Containers Won't Start

**Problem**: `docker compose up` fails

**Solutions**:
1. Check Docker daemon is running
2. Verify sufficient disk space: `df -h`
3. Check port conflicts: `netstat -tlnp | grep :8545`
4. Restart Docker: `sudo systemctl restart docker`

### Clients Not Synchronizing

**Problem**: op-geth and op-reth show different block numbers

**Solutions**:
1. Check P2P connectivity: `docker compose logs op-geth-1 | grep peer`
2. Verify bootnodes configuration in docker-compose.yml
3. Check firewall settings for P2P ports
4. Restart both execution clients: `docker compose restart op-geth-1 op-reth-2`

### eth_simulateV1 Not Available

**Problem**: Method not found errors

**Solutions**:
1. Verify op-reth image: `ghcr.io/unitsnetwork/op-reth:simulate-v1-latest`
2. Check logs: `docker compose logs op-reth-2 | grep simulate`
3. Confirm method spelling: `eth_simulateV1` (capital V)
4. Check HTTP API enabled in docker-compose.yml

### Block Production Stalled

**Problem**: Block number not increasing

**Solutions**:
1. Check validator logs: `docker compose logs lighthouse-validator-1`
2. Verify beacon sync: `curl http://localhost:5052/eth/v1/node/syncing`
3. Check genesis time: `curl http://localhost:5052/eth/v1/beacon/genesis`
4. Restart consensus clients: `docker compose restart lighthouse-node-1 lighthouse-node-2`

### Memory/CPU Issues

**Problem**: High resource usage

**Solutions**:
1. Limit validator count in genesis
2. Reduce Lighthouse target peers
3. Use lighter sync modes for geth
4. Allocate more memory to Docker

### JWT Authentication Errors

**Problem**: Invalid JWT token errors

**Solutions**:
1. Verify JWT secret format (64 hex chars)
2. Check secret mounted correctly: `docker compose exec op-geth-1 cat /etc/jwtsecret.hex`
3. Restart all services: `docker compose down && docker compose up -d`

## Network Management

### Start Services
```bash
docker compose up -d
```

### Stop Services
```bash
docker compose down
```

### View Logs
```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f op-reth-2

# Last 100 lines
docker compose logs --tail=100
```

### Restart Services
```bash
# Single service
docker compose restart op-reth-2

# All services
docker compose restart
```

### Clean State
```bash
# Stop and remove volumes
docker compose down -v

# Then regenerate keys
./scripts/generate-keys.sh
```

### Update Images
```bash
# Pull latest images
docker compose pull

# Rebuild and restart
docker compose up -d --force-recreate
```

## Performance Considerations

- **RAM Usage**: ~8-12GB total for all services
- **CPU**: 4+ cores recommended for smooth operation
- **Disk I/O**: SSD strongly recommended
- **Network**: Stable connection for P2P sync

## Security Notes

⚠️ **This is a TEST network - DO NOT use in production:**
- All private keys are publicly exposed
- JWT secrets are hardcoded
- Network ID is easily guessable
- No firewall protection on ports

For production use:
1. Generate fresh keys
2. Use strong JWT secrets
3. Enable firewall rules
4. Use TLS for RPC endpoints
5. Restrict CORS origins

## Maintenance

### Regular Tasks

1. **Log Rotation**: Clean old logs monthly
   ```bash
   find ./logs -name "*.log" -mtime +30 -delete
   ```

2. **Disk Cleanup**: Remove unused Docker resources
   ```bash
   docker system prune -a --volumes
   ```

3. **Update Images**: Monthly updates
   ```bash
   docker compose pull
   docker compose up -d --force-recreate
   ```

### Backup Strategy

Backup these directories:
```bash
tar -czf backup-$(date +%Y%m%d).tar.gz \
  secrets/ \
  configs/genesis.json \
  .env
```

## Support

For issues related to:
- **op-reth**: https://github.com/UnitsNetwork/op-reth
- **op-geth**: https://github.com/ethereum-optimism/op-geth
- **Lighthouse**: https://github.com/sigp/lighthouse
- **Network issues**: Check logs first, then open GitHub issue

## License

This configuration is provided as-is for testing purposes. See main repository license for details.