# OP-Reth Local Network with eth_simulateV1 Testing

This directory contains a complete local network setup for testing OP-Reth with eth_simulateV1 integration, featuring 2 consensus clients and 2 execution clients.

## Overview

The network consists of:
- **2 Execution Clients**: 
  - `ec-1`: Standard OP-GetH (ghcr.io/unitsnetwork/op-geth:v1.101603.0-1)
  - `ec-2`: Modified OP-Reth with eth_simulateV1 (ghcr.io/unitsnetwork/op-reth:simulate-v1-latest)
- **2 Consensus Clients**:
  - `beacon-1`: Lighthouse beacon node connected to ec-1
  - `beacon-2`: Lighthouse beacon node connected to ec-2
- **2 Validator Clients**:
  - `validator-1`: Lighthouse validator for beacon-1
  - `validator-2`: Lighthouse validator for beacon-2

## Prerequisites

- Docker Engine 29.0+
- Docker Compose (included with Docker)
- `curl` for testing
- `jq` for JSON parsing (for test scripts)
- Linux/macOS environment

## Quick Start

1. **Copy environment file**:
   ```bash
   cp .env.example .env
   ```

2. **Start the network**:
   ```bash
   ./start.sh
   ```

3. **Wait for network to be ready** (approximately 30-60 seconds)

4. **Test eth_simulateV1**:
   ```bash
   ./scripts/test-eth-simulatev1.sh
   ```

5. **Stop the network**:
   ```bash
   ./stop.sh
   ```

## Network Architecture

```
┌─────────────────┐    ┌─────────────────┐
│   Beacon-1      │    │   Beacon-2      │
│ (Lighthouse)    │    │ (Lighthouse)    │
└────────┬────────┘    └────────┬────────┘
         │                      │
         │  Consensus           │  Consensus
         │                      │
┌────────▼────────┐    ┌────────▼────────┐
│     ec-1        │    │     ec-2        │
│   OP-GetH       │    │   OP-Reth       │
│ (Standard)      │    │ (eth_simulate)  │
└────────┬────────┘    └────────┬────────┘
         │                      │
         └──────────┬───────────┘
                    │
            ┌───────▼────────┐
            │   P2P Network  │
            │   (Common)     │
            └────────────────┘
```

## Service Details

### Execution Clients

#### ec-1 (OP-GetH)
- **RPC**: http://127.0.0.1:18545
- **WebSocket**: ws://127.0.0.1:18546
- **Engine API**: http://127.0.0.1:18551
- **P2P**: 127.0.0.1:13030

#### ec-2 (OP-Reth with eth_simulateV1)
- **RPC**: http://127.0.0.1:28545
- **WebSocket**: ws://127.0.0.1:28546
- **Engine API**: http://127.0.0.1:28551
- **P2P**: 127.0.0.1:23030

### Consensus Clients

#### beacon-1
- **API**: http://127.0.0.1:19002
- **P2P**: 127.0.0.1:19000

#### beacon-2
- **API**: http://127.0.0.1:29002
- **P2P**: 127.0.0.1:29000

## Available Scripts

### Network Management
- `./start.sh` - Start the network
- `./stop.sh` - Stop the network (preserves data)
- `./cleanup.sh` - Stop network and remove all data

### Testing
- `./scripts/test-eth-simulatev1.sh` - Test eth_simulateV1 functionality

## Testing eth_simulateV1

The test script performs comprehensive testing:

1. **Network connectivity** - Verify both clients are accessible
2. **Simple simulation** - Test basic block simulation
3. **Transfer simulation** - Test simulation with ETH transfer
4. **Multi-block simulation** - Test multiple sequential blocks

### Manual Testing

You can manually test eth_simulateV1 using curl:

```bash
# Test on OP-Reth
curl -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_simulateV1","params":[{"blockStateCalls":[{"blockOverrides":{},"stateOverrides":{},"calls":[]}]},"latest"],"id":1}' \
  http://127.0.0.1:28545

# Test on OP-GetH
curl -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_simulateV1","params":[{"blockStateCalls":[{"blockOverrides":{},"stateOverrides":{},"calls":[]}]},"latest"],"id":1}' \
  http://127.0.0.1:18545
```

## Configuration Files

### Genesis Configuration
- `configs/ec-common/genesis.json` - Network genesis state
- `configs/beacon-1/config.yaml` - Beacon chain config for network 1
- `configs/beacon-2/config.yaml` - Beacon chain config for network 2
- `configs/beacon-1/genesis.yaml` - Beacon genesis state for network 1
- `configs/beacon-2/genesis.yaml` - Beacon genesis state for network 2

### Security Files
- `configs/ec-common/jwtsecret.hex` - JWT secret for authentication
- `configs/ec-common/p2p-key-*.hex` - P2P private keys

## Monitoring and Debugging

### View Logs
```bash
# All logs
docker compose logs -f

# Specific service
docker compose logs -f ec-1      # OP-GetH logs
docker compose logs -f ec-2      # OP-Reth logs
docker compose logs -f beacon-1  # Beacon node 1 logs
docker compose logs -f beacon-2  # Beacon node 2 logs
```

### Check Service Health
```bash
# Check block production
curl -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  http://127.0.0.1:18545

curl -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  http://127.0.0.1:28545

# Check peer count
curl -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' \
  http://127.0.0.1:18545
```

### Node Information
```bash
# OP-Reth node info
docker compose exec ec-2 reth node-info --datadir /root/.local/share/reth

# OP-GetH node info
docker compose exec ec-1 geth --exec "admin.nodeInfo" attach http://localhost:8545
```

## Troubleshooting

### Common Issues

1. **Port Conflicts**
   - Ensure ports 18545, 28545, 19000-19002, 29000-29002 are available
   - Modify `.env` file to use different ports if needed

2. **Container Not Starting**
   - Check Docker logs: `docker compose logs [service-name]`
   - Ensure sufficient disk space and memory
   - Clear old volumes: `./cleanup.sh`

3. **Nodes Not Syncing**
   - Check P2P connectivity: `docker compose exec ec-1 geth --exec "admin.peers" attach http://localhost:8545`
   - Verify genesis files are identical
   - Check firewall settings

4. **eth_simulateV1 Not Available**
   - Ensure using correct op-reth image: `ghcr.io/unitsnetwork/op-reth:simulate-v1-latest`
   - Check RPC is accessible: `curl http://127.0.0.1:28545 -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'`

### Reset Network State
```bash
./cleanup.sh
./start.sh
```

## Development Notes

### Adding More Validators
To add additional validators:
1. Generate validator keys using Lighthouse tools
2. Add to `configs/validators/`
3. Update docker-compose.yml with new validator services

### Modifying Network Parameters
- Edit `configs/ec-common/genesis.json` for execution layer changes
- Edit `configs/beacon-*/config.yaml` for consensus layer changes
- Regenerate genesis if needed and restart network

### Custom Images
To use custom images, update `.env` file:
```bash
OP_GETH_IMAGE=your-custom-op-geth:latest
OP_RETH_IMAGE=your-custom-op-reth:latest
```

## Testing Results

After running `./scripts/test-eth-simulatev1.sh`, you should see:

```
Testing op-geth (ec-1)
✓ Simple simulation successful on op-geth
✓ Transfer simulation successful on op-geth
✓ Multi-block simulation successful on op-geth

Testing op-reth (ec-2)
✓ Simple simulation successful on op-reth
✓ Transfer simulation successful on op-reth
✓ Multi-block simulation successful on op-reth

Test Summary
✓ op-geth eth_simulateV1 tests passed
✓ op-reth eth_simulateV1 tests passed

All tests passed! eth_simulateV1 is working correctly on both clients.
```

This confirms both execution clients are working correctly with eth_simulateV1.

## Security Considerations

- This is a development/local network setup
- Private keys are exposed in config files (intentional for testing)
- Do not use in production
- Network is isolated and not connected to mainnet

## Contributing

When making changes:
1. Test with `./scripts/test-eth-simulatev1.sh`
2. Ensure both clients behave identically
3. Update documentation if needed
4. Check logs for any warnings/errors

## Support

For issues related to:
- OP-Reth eth_simulateV1 implementation: Check op-reth repository
- Network setup: Check this repository's issues
- Lighthouse: Refer to Sigma Prime documentation
