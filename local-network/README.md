# Units Local Network with eth_simulateV1

This environment sets up a local network with 2 consensus clients (Lighthouse) and 2 execution clients (op-geth and op-reth). It is specifically designed to test the `eth_simulateV1` RPC method.

## Critical Requirement: genesis.json

**IMPORTANT**: The `genesis.json` file must NOT contain any comments (e.g., lines starting with `//` or `/* */`). Even keys that look like comments (e.g., `"//": "comment"`) must be removed. 

Both execution clients (op-geth and op-reth) use the same cleaned `genesis.json` to ensure consistency.

To clean a `genesis.json` from comments, you can use `jq`:
```bash
jq 'walk(if type == "object" then with_entries(select(.key | startswith("//") | not)) else . end)' genesis.json > genesis_clean.json
```

## Setup and Running

1. **Prepare Environment**:
   Ensure you have Docker and Docker Compose installed.

2. **Initialize and Start**:
   The network uses automatic initialization. On the first run, both `op-geth` and `op-reth` will initialize their databases using the provided `genesis.json`.

   ```bash
   ./start.sh
   ```

3. **Verify Health**:
   Check if all containers are running and healthy:
   ```bash
   docker compose ps
   ```

## Testing eth_simulateV1

A dedicated script is provided to test the `eth_simulateV1` method on both clients.

```bash
./scripts/test-eth-simulatev1.sh
```

This script performs:
- A simple block simulation
- A simulation with a transfer transaction
- A multi-block simulation

## Network Structure

- **ec-1**: Standard `op-geth` (Port 18545)
- **ec-2**: Modified `op-reth` with `eth_simulateV1` (Port 28545)
- **beacon-1**: Lighthouse connected to `ec-1`
- **beacon-2**: Lighthouse connected to `ec-2`
- **validator-1/2**: Lighthouse validators

## SHA256 Verification

Current `genesis.json` hash:
`60caef03a5aa4742b7fa528ef79098cd4c3a5be3d8d84f09981744c513f522cc`

Both clients are configured to use the exact same file.
