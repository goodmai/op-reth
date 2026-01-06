#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# RPC endpoints
OP_GETH_RPC="http://127.0.0.1:18545"
OP_RETH_RPC="http://127.0.0.1:28545"

echo "==================================="
echo "Testing eth_simulateV1 Integration"
echo "==================================="
echo ""

# Wait for nodes to be ready
echo -e "${YELLOW}Waiting for nodes to be ready...${NC}"
sleep 10

# Function to check if RPC is available
check_rpc() {
    local endpoint=$1
    local name=$2
    
    echo -e "${YELLOW}Checking $name RPC endpoint...${NC}"
    if curl -s -X POST -H "Content-Type: application/json" \
         --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
         "$endpoint" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ $name RPC is accessible${NC}"
        return 0
    else
        echo -e "${RED}✗ $name RPC is not accessible${NC}"
        return 1
    fi
}

# Function to test eth_simulateV1
test_eth_simulateV1() {
    local endpoint=$1
    local name=$2
    
    echo ""
    echo -e "${YELLOW}Testing eth_simulateV1 on $name...${NC}"
    
    # Get current block number
    CURRENT_BLOCK=$(curl -s -X POST -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
        "$endpoint" | jq -r '.result')
    
    if [ "$CURRENT_BLOCK" = "null" ] || [ -z "$CURRENT_BLOCK" ]; then
        echo -e "${RED}✗ Failed to get current block number from $name${NC}"
        return 1
    fi
    
    echo "Current block number: $CURRENT_BLOCK"
    
    # Test 1: Simple block simulation
    echo -e "\n${YELLOW}Test 1: Simple block simulation${NC}"
    
    RESPONSE=$(curl -s -X POST -H "Content-Type: application/json" \
        --data "{
            \"jsonrpc\": \"2.0\",
            \"method\": \"eth_simulateV1\",
            \"params\": [
                {
                    \"blockStateCalls\": [
                        {
                            \"blockOverrides\": {},
                            \"stateOverrides\": {},
                            \"calls\": []
                        }
                    ]
                },
                \"$CURRENT_BLOCK\"
            ],
            \"id\": 1
        }" \
        "$endpoint")
    
    if echo "$RESPONSE" | jq -e '.result' > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Simple simulation successful on $name${NC}"
        echo "Response: $(echo "$RESPONSE" | jq -c '.result')"
    else
        echo -e "${RED}✗ Simple simulation failed on $name${NC}"
        echo "Response: $RESPONSE"
        return 1
    fi
    
    # Test 2: Simulation with transfer transaction
    echo -e "\n${YELLOW}Test 2: Simulation with transfer transaction${NC}"
    
    # Sample transaction: simple ETH transfer
    TX_DATA="{
        \"from\": \"0xfe3b557e8fb62b89f4916b721be55ceb828dbd73\",
        \"to\": \"0xf17f52151EbEF6C7334FAD080c5704D77216b732\",
        \"value\": \"0xDE0B6B3A7640000\",  # 1 ETH
        \"gas\": \"0x5208\",  # 21000
        \"gasPrice\": \"0x3B9ACA00\"  # 1 Gwei
    }"
    
    RESPONSE2=$(curl -s -X POST -H "Content-Type: application/json" \
        --data "{
            \"jsonrpc\": \"2.0\",
            \"method\": \"eth_simulateV1\",
            \"params\": [
                {
                    \"blockStateCalls\": [
                        {
                            \"blockOverrides\": {},
                            \"stateOverrides\": {},
                            \"calls\": [$TX_DATA]
                        }
                    ]
                },
                \"$CURRENT_BLOCK\"
            ],
            \"id\": 2
        }" \
        "$endpoint")
    
    if echo "$RESPONSE2" | jq -e '.result' > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Transfer simulation successful on $name${NC}"
        echo "Response: $(echo "$RESPONSE2" | jq -c '.result')"
    else
        echo -e "${RED}✗ Transfer simulation failed on $name${NC}"
        echo "Response: $RESPONSE2"
        return 1
    fi
    
    # Test 3: Multiple blocks simulation
    echo -e "\n${YELLOW}Test 3: Multiple blocks simulation${NC}"
    
    RESPONSE3=$(curl -s -X POST -H "Content-Type: application/json" \
        --data "{
            \"jsonrpc\": \"2.0\",
            \"method\": \"eth_simulateV1\",
            \"params\": [
                {
                    \"blockStateCalls\": [
                        {
                            \"blockOverrides\": {},
                            \"stateOverrides\": {},
                            \"calls\": []
                        },
                        {
                            \"blockOverrides\": {},
                            \"stateOverrides\": {},
                            \"calls\": [$TX_DATA]
                        }
                    ]
                },
                \"$CURRENT_BLOCK\"
            ],
            \"id\": 3
        }" \
        "$endpoint")
    
    if echo "$RESPONSE3" | jq -e '.result' > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Multi-block simulation successful on $name${NC}"
        RESULT_LENGTH=$(echo "$RESPONSE3" | jq '.result | length')
        echo "Number of blocks simulated: $RESULT_LENGTH"
    else
        echo -e "${RED}✗ Multi-block simulation failed on $name${NC}"
        echo "Response: $RESPONSE3"
        return 1
    fi
    
    return 0
}

# Main test execution
main() {
    # Check if jq is available
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}Error: jq is required but not installed. Please install jq first.${NC}"
        exit 1
    fi
    
    # Check RPC endpoints
    check_rpc "$OP_GETH_RPC" "op-geth" || exit 1
    check_rpc "$OP_RETH_RPC" "op-reth" || exit 1
    
    echo ""
    echo "==================================="
    echo "Testing op-geth (ec-1)"
    echo "==================================="
    test_eth_simulateV1 "$OP_GETH_RPC" "op-geth"
    GETH_RESULT=$?
    
    echo ""
    echo "==================================="
    echo "Testing op-reth (ec-2)"
    echo "==================================="
    test_eth_simulateV1 "$OP_RETH_RPC" "op-reth"
    RETH_RESULT=$?
    
    # Summary
    echo ""
    echo "==================================="
    echo "Test Summary"
    echo "==================================="
    
    if [ $GETH_RESULT -eq 0 ]; then
        echo -e "${GREEN}✓ op-geth eth_simulateV1 tests passed${NC}"
    else
        echo -e "${RED}✗ op-geth eth_simulateV1 tests failed${NC}"
    fi
    
    if [ $RETH_RESULT -eq 0 ]; then
        echo -e "${GREEN}✓ op-reth eth_simulateV1 tests passed${NC}"
    else
        echo -e "${RED}✗ op-reth eth_simulateV1 tests failed${NC}"
    fi
    
    if [ $GETH_RESULT -eq 0 ] && [ $RETH_RESULT -eq 0 ]; then
        echo ""
        echo -e "${GREEN}All tests passed! eth_simulateV1 is working correctly on both clients.${NC}"
        exit 0
    else
        echo ""
        echo -e "${RED}Some tests failed. Please check the output above.${NC}"
        exit 1
    fi
}

# Run main function
main "$@"
