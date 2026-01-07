# Changelog

## [Unreleased]

### Added

- **eth_simulateV1 Deposit Transaction Support (Type 0x7E)**: Added support for Optimism deposit transactions in the `eth_simulateV1` RPC method. Deposit transactions (Type 0x7E) are now properly handled with:
  - Direct caller setting from `from` field (no signature verification)
  - Optimism-specific fields: `mint`, `sourceHash`, `isSystemTransaction`
  - Gas limit defaults to 30,000,000 for deposits
  - Nonce set to 0 for deposits

### Changed

- **`TryIntoTxEnv` implementation for `OpTransactionRequest`**: Extended to detect and handle deposit transactions separately from regular transactions.

### Fixed

- **Deposit transaction conversion**: Fixed the conversion of `OpTransactionRequest` to `OpTxEnv` to properly set Optimism-specific fields.

### Dependencies

- Updated `op-alloy-consensus` import to include `DEPOSIT_TX_TYPE_ID`
- Added `op-revm` types for `OptimismFields` and `OpTxEnv`

## Technical Details

- **Type 0x7E = 126**: Deposit transaction type identifier
- **Feature Flag**: Requires `op` feature in `reth-rpc-convert`
- **Files Modified**:
  - `crates/rpc/rpc-convert/src/transaction.rs`
  - `crates/rpc/rpc/tests/eth_simulate_v1_tests.rs`
- **Files Added**:
  - `specs/ETH_SIMULATEV1_SPEC.md`
  - `docs/DEPOSIT_TX_PATCH.md`
  - `docs/IMPLEMENTATION_NOTES.md`

## Testing

- Added unit tests in `crates/rpc/rpc/tests/eth_simulate_v1_tests.rs`:
  - Type detection (0x7E = 126)
  - Deserialization of deposit fields
  - Signature field absence verification
  - TxEnv conversion for deposits
  - SimTx conversion for deposits
