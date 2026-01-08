# Support Optimism Deposit Transactions in `eth_simulateV1`

## Goal Description
Enable `eth_simulateV1` to correctly simulate Optimism `Deposit` transactions (type `0x7E`), including User Deposits (Mint) and System Transactions (L1 Attributes). This requires bypassing signature verification for these transaction types and correctly configuring the EVM environment.

## User Review Required
> [!IMPORTANT]
> This change introduces a dummy signature for Deposit transactions during the simulation build process to satisfy type constraints. This is acceptable for simulation but should be verified to not have side effects.

## Proposed Changes

### Data Layer (`crates/rpc/rpc-convert`)

#### [MODIFY] [transaction/op.rs](file:///Users/alexeiboklag/projects/op-reth/crates/rpc/rpc-convert/src/transaction/op.rs)
- Modify `TryIntoSimTx` implementation for `OpTransactionRequest` or create a specific converter.
- Introduce parsing logic for `mint`, `sourceHash`, and `isSystemTx` from `OpTransactionRequest`.
- Note: `op-alloy-rpc-types` `OpTransactionRequest` might already have these fields. If not, we might need a wrapper. Since we can't easily modify `op-alloy-rpc-types`, we will inspect if direct access or `serde_json::Value` fallback is needed, but assuming `op` feature is enabled, we should rely on `OpTransactionRequest`.

### Logic Layer (`crates/rpc/rpc-convert`)

#### [MODIFY] [transaction/op.rs](file:///Users/alexeiboklag/projects/op-reth/crates/rpc/rpc-convert/src/transaction/op.rs)
- Update `TryIntoSimTx::try_into_sim_tx` for `OpTransactionRequest`:
    - Check if transaction type is Deposit (`0x7E` or `126`).
    - If Deposit:
        - Build `TxDeposit` from request fields (`mint`, `source_hash`, `from`, `to`, `gas`, `value`, `input`).
        - Wrap in `OpTxEnvelope::Deposit`.
        - Wrap in `OpTransactionSigned` with a **dummy signature** (empty).
        - Ensure `Recovered` will use the explicit `from` address provided in the request.

### EVM Layer (`crates/rpc/rpc-convert` & `crates/optimism/evm`)

#### [MODIFY] [transaction/op.rs](file:///Users/alexeiboklag/projects/op-reth/crates/rpc/rpc-convert/src/transaction/op.rs)
- Implement or update logic to configure `TxEnv` correctly for System Transactions.
- In `TxEnvConverter` (or equivalent logic in `RpcConvert` implementation for OP):
    - If `isSystemTx` is true:
        - Set `gas_price` to 0 via `TxEnv`.
        - Set `disable_balance_check` to true in `CfgEnv` (if accessible) or handle via `TxEnv` if possible. *Note: `TxEnv` doesn't control `disable_balance_check`. That's usually `CfgEnv`.*
        - `RpcConvert::tx_env` takes `evm_env` which has `cfg_env`.
        - We might need to handle `isSystemTx` by modifying the `CfgEnv` *before* it's used, but `tx_env` returns `TxEnv`.
        - `eth_simulateV1` flow: `resolve_transaction` -> `converter.build_simulate_v1_transaction` -> `execute_transactions`.
        - `execute_transactions` applies pre-execution changes but generally uses one `CfgEnv`.
        - **Challenge**: `eth_simulateV1` usually runs all txs in the same block/cfg environment.
        - However, `TxEnv` has `optimism` fields (like `enveloped_tx`).
        - We need to ensure `revm` treats it as system tx if `is_system_transaction` is set in the envelope. `TxDeposit` has `is_system_transaction` field.

### Orchestration (`crates/rpc/rpc-eth-types` or `crates/rpc/rpc-eth-api`)

#### [MODIFY] [crates/rpc/rpc-eth-types/src/simulate.rs](file:///Users/alexeiboklag/projects/op-reth/crates/rpc/rpc-eth-types/src/simulate.rs)
- Verify `resolve_transaction` correctly propagates the recovered signer.
- Ensure `execute_transactions` doesn't fail for Deposit/System txs.

## Verification Plan

### Automated Tests
- **Unit Tests**: Add tests in `crates/rpc/rpc-convert/src/transaction/op.rs` to verify:
    - deserialization of Deposit fields (if wrapper used).
    - `try_into_sim_tx` produces a `Deposit` envelope for `0x7E`.
    - `is_system_tx` flag is correctly set.

- **E2E Test**:
    - Create `tests/it/rpc/simulate.rs` (or modify existing).
    - Simulate a Deposit Mint transaction + System Tx.
    - Assert success and balance change.

### Manual Verification
- None required if E2E tests pass.
