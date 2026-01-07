# ETH_SIMULATEV1 Specification for Deposit Transactions (Type 0x7E)

## Overview

This specification defines the implementation of `eth_simulateV1` RPC method support for Optimism Deposit Transactions (Type 0x7E) in reth.

**Based on:** op-geth implementation (`internal/ethapi/transaction_args.go`)
**Ported to:** Rust / reth

## Method: eth_simulateV1

### Transaction Type: 0x7E (Deposit Transaction)

Deposit transactions are a special transaction type in Optimism that allows ETH to be deposited from L1 to L2 without a signature verification step.

**Type ID:** `0x7E` (decimal: 126)

### New Fields in TransactionRequest

For Optimism networks, `TransactionRequest` (via `OpTransactionRequest`) supports:

```rust
/// The mint value for deposit transactions (Optimism specific)
#[serde(default, skip_serializing_if = "Option::is_none")]
pub mint: Option<u128>,
/// The source hash for deposit transactions (Optimism specific)
#[serde(default, skip_serializing_if = "Option::is_none", rename = "sourceHash")]
pub source_hash: Option<B256>,
```

### TxEnv Fill Rules for Type 0x7E

When `transaction_type == 0x7E` (or 126):

1. **Caller (Sender):**
   - Set directly from `request.from` without ecrecover signature verification
   - `tx_env.caller = request.from.unwrap_or(Address::ZERO)`

2. **Gas Settings:**
   - `tx_env.gas_limit = request.gas.unwrap_or(30_000_000)`
   - `tx_env.gas_price = request.gas_price.unwrap_or(U256::ZERO)`

3. **Nonce:**
   - Set to 0 if not specified (deposit transactions don't need nonce management)

4. **OptimismFields:**
   ```rust
   #[cfg(feature = "optimism")]
   tx_env.optimism = reth_primitives::revm_primitives::OptimismFields {
       source_hash: request.source_hash,
       mint: request.mint,
       is_system_transaction: Some(false),
       enveloped_tx: None,
   };
   ```

### Key Differences from Regular Transactions

| Aspect | Regular Transaction | Deposit Transaction (0x7E) |
|--------|---------------------|---------------------------|
| Signature | Required (r, s, v) | Not required |
| Caller | Derived via ecrecover | Direct from `from` field |
| Gas Price | From request or network | Usually 0 for deposits |
| Mint Field | Not applicable | Optimism-specific |
| Source Hash | Not applicable | Optimism-specific |

### JSON-RPC Examples

#### Request:
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "eth_simulateV1",
  "params": [{
    "blockStateCalls": [{
      "calls": [{
        "from": "0x742d35Cc6634C0532925a3b844Bc9e7595f7547b",
        "to": "0xd46e8dd67c55d07bb8143fd21701e55f7b45a301",
        "type": "0x7E",
        "mint": "0xde0b6b3a7640000",
        "sourceHash": "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
      }]
    }]
  }]
}
```

#### Response:
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": [{
    "block": {
      "transactions": [{
        "type": "0x7E",
        "from": "0x742d35Cc6634C0532925a3b844Bc9e7595f7547b",
        "to": "0xd46e8dd67c55d07bb8143fd21701e55f7b45a301",
        "gas": "0x493E0",
        "gasPrice": "0x0",
        "mint": "0xde0b6b3a7640000"
      }]
    }
  }]
}
```

## Implementation Details

### Files Modified

1. **`crates/rpc/rpc-convert/src/transaction.rs`**
   - Add `TryIntoTxEnv` implementation for `OpTransactionRequest` with deposit transaction handling
   - Detect `DEPOSIT_TX_TYPE_ID` (0x7E / 126) and skip signature verification

2. **`crates/rpc/rpc-eth-api/src/helpers/call.rs`**
   - Ensure `create_txn_env` passes through Optimism-specific fields

3. **`Cargo.toml` (root)**
   - Ensure `op-revm` feature is available

### Feature Flags

- **`op`**: Enables Optimism support in `reth-rpc-convert`
- **`optimism`**: Enables Optimism EVM configuration in `reth-evm`

## Testing

### Unit Tests Required

1. **Deserialization Test:** Parse `TransactionRequest` with `mint` and `sourceHash`
2. **TxEnv Fill Test:** Verify `fill_tx_env` for Type 0x7E transactions
3. **Type Detection Test:** Verify 126 == 0x7E detection
4. **Signature Check Test:** Ensure deposit transactions work without r/s/v
5. **Integration Test:** E2E test with deposit transaction simulation

## References

- [Ethereum Execution APIs PR #484](https://github.com/ethereum/execution-apis/pull/484)
- [op-geth eth_simulateV1](https://github.com/ethereum-optimism/op-geth/blob/main/internal/ethapi/api.go)
- [Optimism Deposit Transactions](https://github.com/ethereum-optimism/optimism/blob/develop/specs/deposits.md)
