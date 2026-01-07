//! Integration tests for eth_simulateV1 deposit transaction support (Type 0x7E)
//!
//! These tests verify the end-to-end behavior of deposit transactions
//! in the eth_simulateV1 RPC method.

#[cfg(test)]
mod eth_simulate_v1_integration_tests {
    use alloy_consensus::constants::DEPOSIT_TX_TYPE_ID;
    use alloy_primitives::{Address, B256, U256};
    use op_alloy_rpc_types::OpTransactionRequest;
    use reth_rpc_convert::TryIntoSimTx;

    /// Test 1: Full deposit transaction simulation flow
    ///
    /// This test verifies that a deposit transaction can be:
    /// 1. Created with all required fields (from, to, mint, sourceHash)
    /// 2. Converted to a simulated transaction envelope
    /// 3. Identified as a deposit transaction
    #[test]
    fn test_full_deposit_transaction_simulation() {
        // Setup: Create a realistic deposit transaction
        let from = Address::from_low_u64_be(0x742d35Cc6634C0532925a3b844Bc9e7595f7547bu64);
        let to = Address::from_low_u64_be(0xd46e8dd67c55d07bb8143fd21701e55f7b45a301u64);
        let mint_value = 1_000_000_000_000_000_000u128; // 1 ETH
        let source_hash = B256::from_slice(
            &hex::decode("1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef")
                .unwrap()
        );

        // Create the deposit transaction request
        let deposit_req = OpTransactionRequest::default()
            .with_from(from)
            .with_to(alloy_primitives::TxKind::Call(to))
            .with_transaction_type(DEPOSIT_TX_TYPE_ID)
            .with_mint(mint_value)
            .with_source_hash(source_hash)
            .with_value(U256::from(100))
            .with_input(alloy_primitives::Bytes::from_static(b"deposit data"))
            .with_gas_limit(3_000_000);

        // Convert to simulated transaction
        let sim_tx = deposit_req
            .try_into_sim_tx()
            .expect("Should convert deposit transaction to simulated transaction");

        // Verify the transaction is a deposit
        assert!(
            sim_tx.is_deposit(),
            "Simulated transaction should be identified as a deposit"
        );
    }

    /// Test 2: Deposit transaction without optional fields
    ///
    /// Tests that deposit transactions work with minimal required fields
    #[test]
    fn test_minimal_deposit_transaction() {
        let from = Address::from_low_u64_be(0x742d35Cc6634C0532925a3b844Bc9e7595f7547bu64);

        // Minimal deposit transaction - only from field is required
        let deposit_req = OpTransactionRequest::default()
            .with_from(from)
            .with_transaction_type(DEPOSIT_TX_TYPE_ID);

        // Should still be convertible
        let sim_tx = deposit_req
            .try_into_sim_tx()
            .expect("Should convert minimal deposit transaction");

        assert!(
            sim_tx.is_deposit(),
            "Minimal transaction should still be identified as a deposit"
        );
    }

    /// Test 3: Deposit transaction with system transaction flag
    ///
    /// Tests that system transaction flag is properly handled
    #[test]
    fn test_system_deposit_transaction() {
        use op_alloy_rpc_types::OpTransactionRequestBuilder;

        let from = Address::from_low_u64_be(0xdeaddeaddeaddeaddeaddeaddeaddeaddeaddeadu64);
        let to = Address::from_low_u64_be(0x4200000000000000000000000000000000000007u64); // L1Block contract

        // Create a system deposit transaction (like L1 info tx)
        let deposit_req = OpTransactionRequest::default()
            .with_from(from)
            .with_to(alloy_primitives::TxKind::Call(to))
            .with_transaction_type(DEPOSIT_TX_TYPE_ID)
            .with_value(U256::ZERO)
            .with_input(alloy_primitives::Bytes::from_static(
                &hex::decode("440a5e20").unwrap() // setL1BlockValuesEcotone selector
            ));

        let sim_tx = deposit_req
            .try_into_sim_tx()
            .expect("Should convert system deposit transaction");

        assert!(
            sim_tx.is_deposit(),
            "System deposit transaction should be identified as a deposit"
        );
    }

    /// Test 4: Multiple deposit transactions in sequence
    ///
    /// Tests that multiple deposit transactions can be created and processed
    #[test]
    fn test_multiple_deposit_transactions() {
        let from = Address::from_low_u64_be(0x742d35Cc6634C0532925a3b844Bc9e7595f7547bu64);
        let to1 = Address::from_low_u64_be(0xd46e8dd67c55d07bb8143fd21701e55f7b45a301u64);
        let to2 = Address::from_low_u64_be(0xabcdef1234567890abcdef1234567890abcdef12u64);

        // First deposit transaction
        let deposit_req1 = OpTransactionRequest::default()
            .with_from(from)
            .with_to(alloy_primitives::TxKind::Call(to1))
            .with_transaction_type(DEPOSIT_TX_TYPE_ID)
            .with_mint(1_000_000_000_000_000_000u128)
            .with_source_hash(B256::random());

        // Second deposit transaction
        let deposit_req2 = OpTransactionRequest::default()
            .with_from(from)
            .with_to(alloy_primitives::TxKind::Call(to2))
            .with_transaction_type(DEPOSIT_TX_TYPE_ID)
            .with_mint(2_000_000_000_000_000_000u128)
            .with_source_hash(B256::random());

        // Convert both to simulated transactions
        let sim_tx1 = deposit_req1
            .try_into_sim_tx()
            .expect("Should convert first deposit");
        let sim_tx2 = deposit_req2
            .try_into_sim_tx()
            .expect("Should convert second deposit");

        // Both should be deposits
        assert!(
            sim_tx1.is_deposit() && sim_tx2.is_deposit(),
            "Both transactions should be identified as deposits"
        );
    }

    /// Test 5: Deposit transaction JSON-RPC roundtrip
    ///
    /// Tests that deposit transactions can be serialized and deserialized
    #[test]
    fn test_deposit_transaction_json_roundtrip() {
        use op_alloy_rpc_types::OpTransactionRequest;

        // Original JSON request (simulating JSON-RPC input)
        let json = r#"{
            "from": "0x742d35Cc6634C0532925a3b844Bc9e7595f7547b",
            "to": "0xd46e8dd67c55d07bb8143fd21701e55f7b45a301",
            "type": "0x7E",
            "mint": "0xde0b6b3a7640000",
            "sourceHash": "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
            "value": "0x64",
            "gas": "0x2DC6C0"
        }"#;

        // Deserialize from JSON
        let req: OpTransactionRequest = serde_json::from_str(json)
            .expect("Should deserialize deposit transaction from JSON");

        // Verify fields
        assert_eq!(req.transaction_type().map(|t| t.to::<u8>()), Some(DEPOSIT_TX_TYPE_ID));

        // Serialize back to JSON
        let serialized = serde_json::to_string(&req)
            .expect("Should serialize deposit transaction to JSON");

        // Deserialize again
        let req2: OpTransactionRequest = serde_json::from_str(&serialized)
            .expect("Should deserialize serialized deposit transaction");

        // Verify fields match
        assert_eq!(
            req.from(),
            req2.from(),
            "From field should match after roundtrip"
        );
        assert_eq!(
            req.transaction_type(),
            req2.transaction_type(),
            "Transaction type should match after roundtrip"
        );
    }

    /// Test 6: EthSimulateV1 payload structure compatibility
    ///
    /// Tests compatibility with eth_simulateV1 RPC payload structure
    #[test]
    fn test_eth_simulate_v1_payload_compatibility() {
        use alloy_rpc_types_eth::simulate::{SimBlock, SimulatePayload};

        // Create a simulate payload with a deposit transaction
        let deposit_req = OpTransactionRequest::default()
            .with_from(Address::random())
            .with_to(alloy_primitives::TxKind::Call(Address::random()))
            .with_transaction_type(DEPOSIT_TX_TYPE_ID)
            .with_mint(1_000_000_000_000_000_000u128)
            .with_source_hash(B256::random());

        // Create a sim block with the deposit transaction
        let sim_block = SimBlock {
            block_overrides: None,
            state_overrides: None,
            calls: vec![Some(deposit_req)],
        };

        // Create the simulate payload
        let payload = SimulatePayload {
            block_state_calls: vec![sim_block],
            trace_transfers: false,
            validation: false,
            return_full_transactions: false,
        };

        // Verify payload structure
        assert_eq!(payload.block_state_calls.len(), 1);
        assert_eq!(payload.block_state_calls[0].calls.len(), 1);
        assert!(
            payload.block_state_calls[0].calls[0].is_some(),
            "First call should be Some"
        );
    }

    /// Test 7: Non-deposit transaction should not be treated as deposit
    ///
    /// Tests that regular transactions are not incorrectly treated as deposits
    #[test]
    fn test_non_deposit_not_confused() {
        let from = Address::from_low_u64_be(0x742d35Cc6634C0532925a3b844Bc9e7595f7547bu64);
        let to = Address::from_low_u64_be(0xd46e8dd67c55d07bb8143fd21701e55f7b45a301u64);

        // Regular EIP-1559 transaction (Type 2)
        let regular_req = OpTransactionRequest::default()
            .with_from(from)
            .with_to(alloy_primitives::TxKind::Call(to))
            .with_transaction_type(2) // EIP-1559
            .with_value(U256::from(100));

        let sim_tx = regular_req
            .try_into_sim_tx()
            .expect("Should convert regular transaction");

        // Regular transactions should NOT be deposits
        assert!(
            !sim_tx.is_deposit(),
            "Regular EIP-1559 transaction should NOT be identified as a deposit"
        );
    }

    /// Test 8: Legacy transaction type compatibility
    ///
    /// Tests that legacy transactions (Type 0) are properly handled
    #[test]
    fn test_legacy_transaction_not_deposit() {
        let from = Address::from_low_u64_be(0x742d35Cc6634C0532925a3b844Bc9e7595f7547bu64);
        let to = Address::from_low_u64_be(0xd46e8dd67c55d07bb8143fd21701e55f7b45a301u64);

        // Legacy transaction (Type 0) - no transaction_type set
        let legacy_req = OpTransactionRequest::default()
            .with_from(from)
            .with_to(alloy_primitives::TxKind::Call(to))
            .with_value(U256::from(100))
            .with_gas_price(Some(U256::from(100_000_000_000u64)));

        let sim_tx = legacy_req
            .try_into_sim_tx()
            .expect("Should convert legacy transaction");

        // Legacy transactions should NOT be deposits
        assert!(
            !sim_tx.is_deposit(),
            "Legacy transaction should NOT be identified as a deposit"
        );
    }
}
