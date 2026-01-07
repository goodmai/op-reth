# Implementation Notes: Porting eth_simulateV1 from Go (op-geth) to Rust (reth)

## Overview

This document captures the key implementation details and decisions made during the porting of `eth_simulateV1` deposit transaction support from op-geth (Go) to reth (Rust).

## Source Reference: op-geth

**File**: `internal/ethapi/transaction_args.go` and `internal/ethapi/api.go`

**Key Function**: `DoCall` / `Simulate` which handles `eth_simulateV1`

### Go Implementation Pattern

In op-geth, the deposit transaction handling follows this pattern:

```go
// From transaction_args.go
type TransactionArgs struct {
    From                 *common.Address `json:"from"`
    To                   *common.Address `json:"to"`
    Gas                  *uint64         `json:"gas"`
    GasPrice             *uint128        `json:"gasPrice"`
    MaxFeePerGas         *uint128        `json:"maxFeePerGas"`
    Value                *big.Int        `json:"value"`
    Data                 *[]byte         `json:"data"`
    Input                *[]byte         `json:"input"`
   Nonce                *uint64         `json:"nonce"`
    // Optimism-specific fields
    Mint                 *uint128        `json:"mint"`
    SourceHash           *common.Hash    `json:"sourceHash"`
    IsSystemTransaction  *bool           `json:"isSystemTransaction"`
    TransactionType      *uint8          `json:"type"`
}

// In fillTxEnv for deposit transactions
if *args.TransactionType == DEPOSIT_TX_TYPE {
    // No ecrecover - caller is trusted from args.From
    msg.From = *args.From
    
    // Set Optimism fields
    msg.Mint = args.Mint
    msg.SourceHash = args.SourceHash
    msg.IsSystemTransaction = args.IsSystemTransaction
}
```

## Rust Implementation

### File Structure

| Aspect | Go (op-geth) | Rust (reth) |
|--------|--------------|-------------|
| RPC Types | Custom `TransactionArgs` | `alloy_rpc_types_eth::TransactionRequest` + `op_alloy_rpc_types::OpTransactionRequest` |
| EVM Env | `core.Message` | `revm::TxEnv` + `op_revm::OpTxEnv` |
| Conversion | `FillTx` in `state_processor.go` | `TryIntoTxEnv` trait in `reth-rpc-convert` |
| Config | `ChainConfig` | `reth_chainspec::ChainSpec` |

### Key Implementation Details

#### 1. Transaction Type Detection

**Go:**
```go
DEPOSIT_TX_TYPE = 0x7E
if args.TransactionType != nil && *args.TransactionType == DEPOSIT_TX_TYPE {
    // Handle deposit
}
```

**Rust:**
```rust
use op_alloy_consensus::DEPOSIT_TX_TYPE_ID;

let is_deposit = request
    .transaction_type()
    .map(|ty| ty.to::<u8>() == DEPOSIT_TX_TYPE_ID)
    .unwrap_or(false);
```

#### 2. Caller (From) Field Handling

**Go (Deposit):**
```go
// For deposit, caller is trusted directly from args.From
msg.From = *args.From
```

**Rust (Deposit):**
```rust
if is_deposit {
    if let Some(from) = self.from() {
        tx_env.set_caller(from);
    }
}
```

**Key Difference**: In Go, op-geth trusts the `from` field directly for deposits. In Rust, we use `OpTxEnv::set_caller()` which internally handles the Optimism-specific logic.

#### 3. OptimismFields Setup

**Go:**
```go
msg.Mint = args.Mint
msg.SourceHash = args.SourceHash
msg.IsSystemTransaction = args.IsSystemTransaction
```

**Rust:**
```rust
tx_env.optimism = op_revm::OptimismFields {
    source_hash: self.source_hash(),
    mint: self.mint(),
    is_system_transaction: Some(false),
    enveloped_tx: None,
};
```

#### 4. Gas and Pricing

**Go:**
```go
msg.Gas = *args.Gas
msg.GasPrice = *args.GasPrice
if msg.GasPrice == nil {
    msg.GasPrice = new(uint128)
}
```

**Rust:**
```rust
if let Some(gas) = self.gas_limit() {
    tx_env.set_gas_limit(gas);
} else {
    tx_env.set_gas_limit(30_000_000);
}

if let Some(gas_price) = self.gas_price() {
    tx_env.set_gas_price(gas_price);
}
```

## Architectural Decisions

### 1. Using alloy-primitives and op-alloy-rpc-types

Instead of defining custom types like op-geth, reth uses:
- `alloy_rpc_types_eth` for base Ethereum RPC types
- `op_alloy_rpc_types` for Optimism-specific RPC types

This provides:
- Better interoperability
- Consistent serialization/deserialization
- Standardized field naming (`sourceHash` vs `source_hash`)

### 2. Trait-Based Conversion

Instead of monolithic functions, reth uses traits:
- `TryIntoTxEnv`: Converts RPC request to EVM transaction environment
- `TryIntoSimTx`: Converts RPC request to simulated transaction
- `SignableTxRequest`: For signing transactions

This allows:
- Generic implementations
- Easy customization per network type
- Testable code

### 3. Feature Flags

The Optimism support is gated behind the `op` feature flag:
- `reth-rpc-convert` crate: `op = [...]` in Cargo.toml
- Enables `op-alloy-*` dependencies
- Conditionally compiles `TryIntoTxEnv` implementation

## Testing Strategy

### Unit Tests

Located in `crates/rpc/rpc/tests/eth_simulate_v1_tests.rs`:

1. **Type Detection**: Verify 0x7E = 126
2. **Deserialization**: Parse mint and sourceHash from JSON
3. **Signature Check**: Deposit tx doesn't require r/s/v
4. **TxEnv Conversion**: Verify caller set directly
5. **SimTx Conversion**: Verify OpTxEnvelope created

### Integration Tests

Recommended tests (not implemented yet):
- Full eth_simulateV1 RPC call with deposit transaction
- Compare output with op-geth for same inputs
- Test with and without validation mode

## Known Limitations and Future Work

1. **Validation Mode**: The `validation` flag in `eth_simulateV1` that enables signature verification for deposits is not yet implemented
2. **System Transactions**: The `is_system_transaction` field could be made configurable
3. **Enveloped TX**: The `enveloped_tx` field is set to None; could be populated for L1-to-L2 transactions

## References

- [op-geth transaction_args.go](https://github.com/ethereum-optimism/op-geth/blob/main/internal/ethapi/transaction_args.go)
- [op-geth api.go DoCall](https://github.com/ethereum-optimism/op-geth/blob/main/internal/ethapi/api.go)
- [reth-rpc-convert transaction.rs](https://github.com/paradigmxyz/reth/blob/main/crates/rpc/rpc-convert/src/transaction.rs)
- [Optimism Deposits Specification](https://github.com/ethereum-optimism/optimism/blob/develop/specs/deposits.md)
