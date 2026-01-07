//! Unit tests for eth_simulateV1 deposit transaction support (Type 0x7E)

#[cfg(test)]
mod deposit_transaction_tests {
    use alloy_consensus::constants::DEPOSIT_TX_TYPE_ID;
    use alloy_primitives::{Address, B256, U256};
    use alloy_rpc_types_eth::request::TransactionRequest;
    use op_alloy_consensus::OpTxEnvelope;
    use op_alloy_rpc_types::OpTransactionRequest;
    use reth_rpc_convert::{TryIntoSimTx, TryIntoTxEnv};
    use revm::context::BlockEnv;

    /// Test 1: Verify that Type 0x7E = 126 is correctly identified as DEPOSIT_TX_TYPE_ID
    #[test]
    fn test_deposit_transaction_type_detection() {
        // 0x7E in hexadecimal = 126 in decimal
        let deposit_type_hex = 0x7Eu64;
        let deposit_type_dec: u8 = DEPOSIT_TX_TYPE_ID;

        assert_eq!(
            deposit_type_hex, 126,
            "0x7E should equal 126 in decimal"
        );
        assert_eq!(
            deposit_type_dec, 126,
            "DEPOSIT_TX_TYPE_ID should be 126"
        );
        assert_eq!(
            deposit_type_hex as u8, deposit_type_dec,
            "0x7E and DEPOSIT_TX_TYPE_ID should be equal"
        );
    }

    /// Test 2: Deserialize OpTransactionRequest with mint and sourceHash fields
    #[test]
    fn test_op_transaction_request_deserialization() {
        // JSON with deposit-specific fields (mint and sourceHash)
        let json = r#"{
            "from": "0x742d35Cc6634C0532925a3b844Bc9e7595f7547b",
            "to": "0xd46e8dd67c55d07bb8143fd21701e55f7b45a301",
            "type": "0x7E",
            "mint": "0xde0b6b3a7640000",
            "sourceHash": "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
        }"#;

        // Deserialize
        let req: OpTransactionRequest = serde_json::from_str(json).expect("Should deserialize");

        // Verify transaction type
        assert_eq!(req.transaction_type().map(|t| t.to::<u8>()), Some(DEPOSIT_TX_TYPE_ID));
    }

    /// Test 3: Verify deposit transaction does NOT require r, s, v signature fields
    #[test]
    fn test_deposit_transaction_no_signature_required() {
        // Deposit transaction JSON WITHOUT r, s, v fields
        let json = r#"{
            "from": "0x742d35Cc6634C0532925a3b844Bc9e7595f7547b",
            "to": "0xd46e8dd67c55d07bb8143fd21701e55f7b45a301",
            "type": "0x7E",
            "mint": "0xde0b6b3a7640000",
            "sourceHash": "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
        }"#;

        // Should deserialize successfully even without signature fields
        let req: OpTransactionRequest = serde_json::from_str(json).expect("Should deserialize");

        // Verify that signature fields are not set
        assert!(req.signature().is_none(), "Deposit tx should not have signature");
    }

    /// Test 4: TryIntoTxEnv for deposit transaction (Type 0x7E)
    #[test]
    fn test_try_into_tx_env_deposit_transaction() {
        use reth_rpc_convert::TryIntoTxEnv;

        // Create a minimal EVM env
        let block_env = BlockEnv {
            number: U256::from(100),
            timestamp: U256::from(1000),
            ..Default::default()
        };
        let cfg_env = reth_evm::ConfigureEvm::cfg_env_for(&reth_chainspec::ChainSpec::default());
        let evm_env = alloy_evm::EvmEnv::new(cfg_env, block_env);

        // Create deposit transaction request
        let from = Address::from_low_u64_be(0x742d35Cc6634C0532925a3b844Bc9e7595f7547bu64);
        let to = Address::from_low_u64_be(0xd46e8dd67c55d07bb8143fd21701e55f7b45a301u64);

        let deposit_req = OpTransactionRequest::default()
            .with_from(from)
            .with_to(alloy_primitives::TxKind::Call(to))
            .with_transaction_type(DEPOSIT_TX_TYPE_ID)
            .with_mint(1_000_000_000_000_000_000u128)
            .with_source_hash(B256::random())
            .with_gas_limit(3_000_000)
            .with_value(U256::from(100));

        // Convert to TxEnv
        let tx_env = deposit_req
            .try_into_tx_env(&evm_env)
            .expect("Should convert deposit transaction to TxEnv");

        // Verify caller is set directly (no ecrecover)
        assert_eq!(tx_env.caller, from, "Caller should be set from 'from' field");

        // Verify gas limit
        assert_eq!(tx_env.gas_limit, 3_000_000, "Gas limit should be set from request");

        // Verify nonce is 0 for deposit
        assert_eq!(tx_env.nonce, Some(0), "Nonce should be 0 for deposit transactions");

        // Verify Optimism fields are set
        assert!(
            tx_env.optimism.is_some(),
            "Optimism fields should be Some for deposit transaction"
        );
        let optimism = tx_env.optimism.unwrap();
        assert_eq!(
            optimism.mint,
            Some(1_000_000_000_000_000_000u128),
            "Mint should be set"
        );
        assert!(
            optimism.source_hash.is_some(),
            "Source hash should be set"
        );
        assert_eq!(
            optimism.is_system_transaction,
            Some(false),
            "is_system_transaction should be false for user deposits"
        );
    }

    /// Test 5: TryIntoTxEnv for non-deposit transaction should use standard conversion
    #[test]
    fn test_try_into_tx_env_non_deposit_transaction() {
        use reth_rpc_convert::TryIntoTxEnv;

        // Create a minimal EVM env
        let block_env = BlockEnv {
            number: U256::from(100),
            timestamp: U256::from(1000),
            ..Default::default()
        };
        let cfg_env = reth_evm::ConfigureEvm::cfg_env_for(&reth_chainspec::ChainSpec::default());
        let evm_env = alloy_evm::EvmEnv::new(cfg_env, block_env);

        // Create a regular EIP-1559 transaction request (Type 2)
        let from = Address::from_low_u64_be(0x742d35Cc6634C0532925a3b844Bc9e7595f7547bu64);
        let to = Address::from_low_u64_be(0xd46e8dd67c55d07bb8143fd21701e55f7b45a301u64);

        let regular_req = OpTransactionRequest::default()
            .with_from(from)
            .with_to(alloy_primitives::TxKind::Call(to))
            .with_transaction_type(2) // EIP-1559
            .with_gas_limit(21_000)
            .with_value(U256::from(100))
            .with_max_fee_per_gas(U256::from(100_000_000_000u64))
            .with_max_priority_fee_per_gas(U256::from(10_000_000_000u64));

        // Convert to TxEnv
        let tx_env = regular_req
            .try_into_tx_env(&evm_env)
            .expect("Should convert regular transaction to TxEnv");

        // For non-deposit transactions, we expect a regular TxEnv (not OpTxEnv)
        // The conversion should use standard logic
        assert_eq!(tx_env.caller, from, "Caller should be set");
        assert_eq!(tx_env.gas_limit, 21_000, "Gas limit should be set");
    }

    /// Test 6: TryIntoSimTx for deposit transaction
    #[test]
    fn test_try_into_sim_tx_deposit_transaction() {
        use reth_rpc_convert::TryIntoSimTx;

        // Create a deposit transaction request
        let from = Address::from_low_u64_be(0x742d35Cc6634C0532925a3b844Bc9e7595f7547bu64);
        let to = Address::from_low_u64_be(0xd46e8dd67c55d07bb8143fd21701e55f7b45a301u64);

        let deposit_req = OpTransactionRequest::default()
            .with_from(from)
            .with_to(alloy_primitives::TxKind::Call(to))
            .with_transaction_type(DEPOSIT_TX_TYPE_ID)
            .with_mint(1_000_000_000_000_000_000u128)
            .with_source_hash(B256::random())
            .with_value(U256::from(100))
            .with_input(alloy_primitives::Bytes::from_static(b"hello"));

        // Convert to simulated transaction
        let sim_tx: OpTxEnvelope = deposit_req
            .try_into_sim_tx()
            .expect("Should convert to simulated transaction");

        // Verify it's a deposit transaction
        assert!(
            sim_tx.is_deposit(),
            "Converted transaction should be a deposit"
        );
    }

    /// Test 7: Verify OpTransactionRequest implements proper conversion to TransactionRequest
    #[test]
    fn test_op_transaction_request_into_transaction_request() {
        let from = Address::from_low_u64_be(0x742d35Cc6634C0532925a3b844Bc9e7595f7547bu64);
        let to = Address::from_low_u64_be(0xd46e8dd67c55d07bb8143fd21701e55f7b45a301u64);

        let op_req = OpTransactionRequest::default()
            .with_from(from)
            .with_to(alloy_primitives::TxKind::Call(to))
            .with_value(U256::from(100))
            .with_gas_limit(21_000);

        // Convert to base TransactionRequest
        let base_req: TransactionRequest = op_req.into();

        assert_eq!(base_req.from(), Some(from));
        assert_eq!(base_req.to(), Some(Some(to).into()));
        assert_eq!(base_req.value(), Some(U256::from(100)));
        assert_eq!(base_req.gas_limit(), Some(21_000));
    }

    /// Test 8: Verify default gas limit for deposit transactions
    #[test]
    fn test_deposit_transaction_default_gas_limit() {
        use reth_rpc_convert::TryIntoTxEnv;

        // Create a minimal EVM env
        let block_env = BlockEnv {
            number: U256::from(100),
            timestamp: U256::from(1000),
            ..Default::default()
        };
        let cfg_env = reth_evm::ConfigureEvm::cfg_env_for(&reth_chainspec::ChainSpec::default());
        let evm_env = alloy_evm::EvmEnv::new(cfg_env, block_env);

        // Create deposit transaction request WITHOUT gas limit
        let from = Address::from_low_u64_be(0x742d35Cc6634C0532925a3b844Bc9e7595f7547bu64);
        let to = Address::from_low_u64_be(0xd46e8dd67c55d07bb8143fd21701e55f7b45a301u64);

        let deposit_req = OpTransactionRequest::default()
            .with_from(from)
            .with_to(alloy_primitives::TxKind::Call(to))
            .with_transaction_type(DEPOSIT_TX_TYPE_ID)
            .with_mint(1_000_000_000_000_000_000u128)
            .with_source_hash(B256::random());

        // Convert to TxEnv
        let tx_env = deposit_req
            .try_into_tx_env(&evm_env)
            .expect("Should convert deposit transaction to TxEnv");

        // Verify default gas limit (30_000_000)
        assert_eq!(
            tx_env.gas_limit, 30_000_000,
            "Default gas limit should be 30_000_000 for deposit transactions"
        );
    }

    /// Test 9: Verify deposit transaction type detection from various inputs
    #[test]
    fn test_deposit_type_detection_variants() {
        use op_alloy_consensus::DEPOSIT_TX_TYPE_ID;

        // Test that 0x7E == 126 == DEPOSIT_TX_TYPE_ID
        let type_0x7e = 0x7Eu64;
        let type_126 = 126u64;
        let type_from_const: u8 = DEPOSIT_TX_TYPE_ID;

        assert_eq!(type_0x7e as u8, type_from_const);
        assert_eq!(type_126 as u8, type_from_const);
        assert_eq!(type_0x7e as u8, type_126 as u8);
    }
}
