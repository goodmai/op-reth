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

## 2. Декомпозиция задач (Tasks)

### Task 1: Интеграция расширенных типов RPC (Data Layer)

**Приоритет:** Blocker
**Сложность:** Low
**Файлы:** `crates/rpc/rpc-types/src/eth/transaction/` (или локально в модуле simulate).

**Описание:**
Метод `eth_simulateV1` должен уметь принимать JSON с полями депозита.

1. Проверить наличие крейта `op-alloy-rpc-types` в зависимостях. Если нет — добавить.
2. Если использование `op-alloy` невозможно из-за конфликтов версий, объявить локальную структуру-обертку.

**Техническая реализация:**

```rust
#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct OpSimulateTransactionRequest {
    #[serde(flatten)]
    pub inner: TransactionRequest, // Стандартные поля
    pub mint: Option<U128>,        // Optimism specific
    #[serde(rename = "sourceHash")]
    pub source_hash: Option<B256>, // Optimism specific
    #[serde(rename = "isSystemTx")]
    pub is_system_tx: Option<bool>,
}

```

**DoD (Definition of Done):**

* [ ] Структура `OpSimulateTransactionRequest` компилируется.
* [ ] Написан Unit-тест: JSON строка с `sourceHash` успешно десериализуется, поле доступно в Rust.
* [ ] Поля `mint` и `sourceHash` корректно маппятся в `Option`.

---

### Task 2: Реализация конвертера `OpTxBuilder` (Logic Layer)

**Приоритет:** Critical
**Сложность:** High
**Файлы:** `crates/rpc/rpc-eth-api/src/helpers/call.rs` (или аналогичный в `optimism` feature).

**Описание:**
Необходимо научить ноду преобразовывать "сырой" RPC запрос в примитив транзакции, понятный движку Reth, **без валидации подписи**.

**Техническая реализация:**

1. Создать функцию-хелпер `try_build_deposit_tx`.
2. Логика:
* Если `tx_type != 0x7E`, вернуть `None` (пусть обрабатывается стандартно).
* Если `0x7E`:
* Проверить наличие `from` (обязательно).
* Сконструировать `reth_optimism_primitives::DepositTransaction`.
* Обернуть в `TransactionSigned` (с пустым полем signature).
* Вернуть `Recovered<TransactionSigned>` где `signer` явно установлен в `req.from`.





**DoD:**

* [ ] Функция `try_build_deposit_tx` реализована и компилируется.
* [ ] Unit-тест: На вход подается Request с типом `0x7E`, на выходе — `Recovered` транзакция с корректным адресом отправителя.
* [ ] Отсутствуют вызовы `ecrecover` внутри этого флоу.

---

### Task 3: Интеграция в пайплайн `simulate_v1` (Orchestration)

**Приоритет:** Critical
**Сложность:** Medium
**Файлы:** `crates/rpc/rpc-eth-api/src/eth_api.rs` (метод `simulate_v1`).

**Описание:**
Заменить стандартный итератор по транзакциям на логику, поддерживающую ветвление.

**Техническая реализация:**
В цикле обработки транзакций `SimulateV1Request`:

```rust
let tx = if request.is_deposit() {
    Self::try_build_deposit_tx(request)? // Логика из Task 2
} else {
    // Стандартная логика с recover_signer
    TransactionRequest::try_into_recovered(request)?
};

```

*Важно:* Убедиться, что `OpEvmConfig` используется для создания EVM, иначе новые поля транзакции будут проигнорированы при исполнении.

**DoD:**

* [ ] Проект компилируется целиком (`cargo check`).
* [ ] Интеграция не ломает существующие тесты для Legacy транзакций (Run `cargo test -p reth-rpc`).

---

### Task 4: Обработка системных транзакций и Газа (EVM Layer)

**Приоритет:** Medium
**Сложность:** High
**Файлы:** `crates/optimism/evm/src/lib.rs` (конфигурация `TxEnv`).

**Описание:**
Обеспечить корректное исполнение L1 Attributes транзакций (обновление L2 состояния).

**Техническая реализация:**

1. При конфигурации `TxEnv` для `revm`:
* Если `tx.is_system_transaction`:
* Установить `env.tx.gas_price = 0`.
* Установить `env.cfg.disable_balance_check = true` (или `disable_block_gas_limit`).




2. Для `mint` операций: убедиться, что `revm` корректно начисляет баланс на `to` адрес перед исполнением (или в процессе, если это нативная функция OP-стека).

**DoD:**

* [ ] Unit-тест: Симуляция транзакции с `isSystemTx: true` от адреса с балансом 0 проходит успешно (Success), а не падает с ошибкой `OutOfFunds`.

---

### Task 5: Финальное E2E Тестирование

**Приоритет:** High
**Сложность:** Medium
**Файлы:** `tests/it/rpc/simulate.rs`.

**Описание:**
Проверка всего сценария целиком.

**Сценарий теста:**

1. **Setup:** Запустить `Reth` с флагом `optimism`.
2. **Action:** Вызвать `eth_simulateV1` с массивом из одной транзакции:
* `type`: "0x7E"
* `mint`: "1000000000000000000" (1 ETH)
* `to`: "0x123..."
* `sourceHash`: "0x..."


3. **Assert:**
* RPC возвращает статус Success.
* В поле `balanceChanges` для адреса `0x123...` видно увеличение на 1 ETH.



**DoD:**

* [ ] Тест проходит (`PASSED`).
* [ ] Отсутствуют паники в логах ноды.

---

## Резюме для разработчика

Я рекомендую начать с **Task 1**, так как без корректного парсинга JSON дальнейшая работа бессмысленна. Сразу после этого переходите к **Task 2** и **Task 3** в связке — это ядро функционала. Task 4 можно дорабатывать итеративно, проверяя корректность списания газа.

**Команда:**
`cargo test --package reth-rpc-eth-api` — ваша главная команда на ближайшие дни.
