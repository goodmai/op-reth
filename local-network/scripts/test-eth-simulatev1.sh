#!/bin/bash

echo "eth_simulateV1 Compatibility Test Suite"
echo "========================================"

# Store the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

declare -i FINAL_RESULT=0

function report_test_result() {
    local test_name="$1"
    local test_result="$2"
    
    if [[ $test_result -eq 0 ]]; then
        echo "✅ PASSED: $test_name"
    else
        echo "❌ FAILED: $test_name"
        FINAL_RESULT=1
    fi
}

function test_basic_connection() {
    local client_name="$1"
    local port="$2"
    
    echo "Testing $client_name connection on port $port..."
    
    local response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
        http://localhost:${port} 2>&1)
    
    if [[ $? -eq 0 ]] && echo "$response" | grep -q '"result"'; then
        echo "✅ $client_name RPC is accessible"
        return 0
    else
        echo "❌ $client_name RPC is not accessible"
        return 1
    fi
}

function test_eth_simulatev1_basic() {
    local client_name="$1"
    local port="$2"
    
    echo "Testing eth_simulateV1 on $client_name..."
    
    local response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"eth_simulateV1","params":[{"blockStateCalls":[{"blockOverride":{"number":"0x1"},"stateOverrides":{"0x0000000000000000000000000000000000000000":{"balance":"0xde0b6b3a7640000"}},"calls":[{"from":"0xfe3b557e8fb62b89f4916b721be55ceb828dbd73","to":"0x0000000000000000000000000000000000000000","gas":"0x5208","gasPrice":"0x3b9aca00","value":"0x1"}]}]}],"id":1}' \
        http://localhost:${port} 2>&1)
    
    if [[ $? -eq 0 ]] && echo "$response" | grep -q '"result"'; then
        echo "✅ eth_simulateV1 works on $client_name"
        return 0
    else
        echo "❌ eth_simulateV1 failed on $client_name"
        return 1
    fi
}

function test_simulation_consistency() {
    echo "Testing simulation results consistency between clients..."
    
    # Get simulation result from op-geth
    local geth_result=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"eth_simulateV1","params":[{"blockStateCalls":[{"blockOverride":{"number":"0x1"},"calls":[{"from":"0xfe3b557e8fb62b89f4916b721be55ceb828dbd73","gas":"0x5208","gasPrice":"0x3b9aca00"}]}]}],"id":1}' \
        http://localhost:8545 2>&1)
    
    # Get simulation result from op-reth
    local reth_result=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"eth_simulateV1","params":[{"blockStateCalls":[{"blockOverride":{"number":"0x1"},"calls":[{"from":"0xfe3b557e8fb62b89f4916b721be55ceb828dbd73","gas":"0x5208","gasPrice":"0x3b9aca00"}]}]}],"id":1}' \
        http://localhost:8547 2>&1)
    
    # Extract results for comparison
    local geth_responses=$(echo "geth_result" | grep -o '"responses":\[[^]]*\]')
    local reth_responses=$(echo "reth_result" | grep -o '"responses":\[[^]]*\]')
    
    if [[ "$geth_responses" == "$reth_responses" ]]; then
        echo "✅ Simulation results are consistent between clients"
        return 0
    else
        echo "❌ Simulation results differ between clients"
        return 1
    fi
}

function test_block_production() {
    echo "Testing block production..."
    
    local geth_block_1=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
        http://localhost:8545 | grep -o '"result":"0x[^"]*"' | cut -d'"' -f4)
    
    sleep 15
    
    local geth_block_2=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
        http://localhost:8545 | grep -o '"result":"0x[^"]*"' | cut -d'"' -f4)
    
    if [[ "$geth_block_1" != "$geth_block_2" ]]; then
        echo "✅ Blocks are being produced"
        return 0
    else
        echo "❌ No block production detected"
        return 1
    fi
}

function test_client_synchronization() {
    echo "Testing client synchronization..."
    
    local geth_block=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
        http://localhost:8545 2>&1 | grep -o '"result":"0x[^"]*"' | cut -d'"' -f4)
    
    local reth_block=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
        http://localhost:8547 2>&1 | grep -o '"result":"0x[^"]*"' | cut -d'"' -f4)
    
    if [[ "$geth_block" == "$reth_block" ]]; then
        echo "✅ Clients are synchronized at block $geth_block"
        return 0
    else
        echo "⚠️  Clients not synchronized (geth: $geth_block, reth: $reth_block)"
        return 1
    fi
}

echo "Network Health Check"
echo "===================="

test_basic_connection "op-geth" "8545"
report_test_result "op-geth connection" $?

test_basic_connection "op-reth" "8547"
report_test_result "op-reth connection" $?

echo ""
echo "eth_simulateV1 Tests"
echo "===================="

test_eth_simulatev1_basic "op-geth" "8545"
report_test_result "eth_simulatev1 on op-geth" $?

test_eth_simulatev1_basic "op-reth" "8547"
report_test_result "eth_simulatev1 on op-reth" $?

test_simulation_consistency
report_test_result "simulation consistency" $?

echo ""
echo "Network Synchronization Tests"
echo "=============================="

test_block_production
report_test_result "block production" $?

test_client_synchronization
report_test_result "client synchronization" $?

echo ""
echo "Final Results"
echo "============="

if [[ $FINAL_RESULT -eq 0 ]]; then
    echo "✅ All tests PASSED"
else
    echo "❌ Some tests FAILED"
fi

exit $FINAL_RESULT