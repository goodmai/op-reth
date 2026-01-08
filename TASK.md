Как старший блокчейн-архитектор, я провел анализ зависимостей (`alloy-rpc-types`, `reth-rpc-layer`) и подтверждаю: **стандартная структура `TransactionRequest` не содержит полей `mint`, `sourceHash` и `isSystemTx`.** Без явного расширения типов (Task 1) реализация невозможна.

Ниже представлен финальный, **тщательно декомпозированный Эпик**, составленный с учетом архитектуры `reth` (использование `alloy`, модульность `revm`) и требований к DoD.

---

# EPIC: Поддержка Optimism Deposit Transactions в `eth_simulateV1`

**ID:** `EPIC-OP-SIM-001`
**Цель:** Обеспечить корректную симуляцию транзакций типа `0x7E` (Deposit) через RPC метод `eth_simulateV1`, включая User Deposits (Mint) и System Transactions (L1 Attributes), обходя проверку подписей.
**Стек:** Rust, Reth, Optimism Primitives, Alloy.

## 1. Архитектурный анализ и Зоны влияния (Impact Analysis)

### Затрагиваемые компоненты

1. **RPC Interface (`crates/rpc/rpc-types-compat` & `rpc-api`)**:
* Текущий `SimulateV1Request` использует стандартный `TransactionRequest`. Он не сможет десериализовать поля `mint` (u128) и `sourceHash` (B256).
* **Решение**: Необходимо внедрить `OpTransactionRequest` (из `op-alloy-rpc-types` или кастомный), который поддерживает `flatten` полей депозита.


2. **Transaction Resolution (`crates/rpc/rpc-eth-api/src/helpers/`)**:
* Классы: `EthApi`, трейт `EthCall`.
* Проблема: Метод `transact_call` или `build_call_evm_env` вызывает `recover_signer`. Для депозитов это вызывает панику/ошибку.
* **Решение**: Реализовать ветвление логики: если `tx_type == 0x7E`, использовать `source_hash` и `from` напрямую, минуя криптографию.


3. **EVM Configuration (`crates/optimism/evm/`)**:
* Классы: `OpExecutorProvider`, `OpEvmConfig`.
* Проблема: Системные транзакции требуют флага `disable_balance_check`.
* **Решение**: Маппинг флага `isSystemTx` из RPC запроса в настройки `TxEnv` `revm`.



---

## 2. Tasks

### Task 1: Data & Logic Layer Implementation (`crates/rpc/rpc-convert`)

**Priority:** Critical
**Files:** `crates/rpc/rpc-convert/src/transaction.rs`

- [ ] **[NEW]** Define `OpSimulateTransactionRequest` local struct:
    - Include standard transaction fields.
    - Include Deposit-specific fields (`mint`, `source_hash`, `is_system_tx`).
    - Use `serde` for flexible deserialization.
- [ ] **[MODIFY]** Implement `TryIntoSimTx<OpTxEnvelope>` for `OpSimulateTransactionRequest`.
- [ ] **[MODIFY]** Update `RpcConvert` trait:
    - Add `fn build_simulate_v1_transaction_from_json`.
- [ ] **[MODIFY]** Implement `build_simulate_v1_transaction_from_json` for `OpRpcConvert`.

### Task 2: Orchestration Layer Integration (`crates/rpc`)

**Priority:** High
**Files:** `rpc-eth-api/src/core.rs`, `rpc-eth-api/src/helpers/call.rs`, `rpc-eth-types/src/simulate.rs`

- [ ] **[MODIFY]** Update `EthApi::simulate_v1` signature check to accept `SimulatePayload<serde_json::Value>`.
- [ ] **[MODIFY]** Update `EthCall::simulate_v1` signature and implementation.
- [ ] **[MODIFY]** Update `execute_transactions` in `rpc-eth-types` to accept `Vec<serde_json::Value>` and use the JSON converter.

### Task 3: EVM Layer Configuration

**Priority:** High
**Files:** `crates/optimism/evm`

- [ ] Verify `TxDeposit` execution environment (gas price, balance checks) handles system transactions correctly.

### Task 4: Verification

**Priority:** Medium

- [ ] Add E2E Test for Optimism Deposit Simulation.

