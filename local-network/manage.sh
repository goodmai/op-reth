#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
NETWORK_DIR="$SCRIPT_DIR"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

function log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

function log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

function log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

function check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    if ! command -v docker compose &> /dev/null; then
        log_error "Docker Compose is not installed or not in PATH"
        exit 1
    fi
    
    if ! command -v curl &> /dev/null; then
        log_error "curl is not installed or not in PATH"
        exit 1
    fi
    
    log_info "All prerequisites satisfied"
}

function setup_environment() {
    log_info "Setting up environment..."
    
    cd "$NETWORK_DIR"
    
    # Create .env if it doesn't exist
    if [[ ! -f ".env" ]]; then
        if [[ -f ".env.example" ]]; then
            cp .env.example .env
            log_info "Created .env from .env.example"
        else
            log_error ".env.example not found"
            exit 1
        fi
    else
        log_info ".env already exists"
    fi
    
    # Generate keys if needed
    if [[ ! -f "secrets/jwtsecret.hex" ]]; then
        log_info "Generating JWT secret..."
        mkdir -p secrets
        openssl rand -hex 32 > secrets/jwtsecret.hex
    fi
    
    # Create consensus config directory
    mkdir -p configs/consensus
    
    log_info "Environment setup complete"
}

function start_network() {
    log_info "Starting local network..."
    
    cd "$NETWORK_DIR"
    
    # Pull latest images
    log_info "Pulling Docker images..."
    docker compose pull
    
    # Start services
    log_info "Starting services..."
    docker compose up -d
    
    log_info "Network started successfully"
    log_info "Waiting for services to initialize..."
    
    # Wait for health checks
    sleep 30
    
    check_network_health
}

function stop_network() {
    log_info "Stopping local network..."
    
    cd "$NETWORK_DIR"
    docker compose down
    
    log_info "Network stopped successfully"
}

function restart_network() {
    log_info "Restarting local network..."
    
    stop_network
    sleep 5
    start_network
}

function clean_network() {
    log_warn "Cleaning network state (this will remove all data)..."
    
    cd "$NETWORK_DIR"
    docker compose down -v
    
    # Clean data directories
    rm -rf data/
    rm -rf secrets/validator-keys-*
    
    log_info "Network state cleaned"
}

function check_network_health() {
    log_info "Checking network health..."
    
    local healthy_services=0
    local total_services=6
    
    cd "$NETWORK_DIR"
    
    # Check if containers are running
    for service in op-geth-1 op-reth-2 lighthouse-node-1 lighthouse-node-2 lighthouse-validator-1 lighthouse-validator-2; do
        if docker compose ps | grep -q "${service}.*Up"; then
            log_info "✅ $service is running"
            ((healthy_services++))
        else
            log_error "❌ $service is not running"
        fi
    done
    
    # Check RPC endpoints
    log_info "Checking RPC endpoints..."
    
    if curl -s -X POST http://localhost:8545 \
        -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' > /dev/null 2>&1; then
        log_info "✅ op-geth RPC is responsive"
        ((healthy_services++))
    else
        log_error "❌ op-geth RPC is not responsive"
    fi
    
    if curl -s -X POST http://localhost:8547 \
        -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' > /dev/null 2>&1; then
        log_info "✅ op-reth RPC is responsive"
        ((healthy_services++))
    else
        log_error "❌ op-reth RPC is not responsive"
    fi
    
    log_info "Network health: $healthy_services/$total_services services healthy"
    
    if [[ $healthy_services -eq $total_services ]]; then
        return 0
    else
        return 1
    fi
}

function show_logs() {
    local service="$1"
    local follow="$2"
    
    cd "$NETWORK_DIR"
    
    if [[ -n "$service" ]]; then
        if [[ "$follow" == "follow" ]]; then
            docker compose logs -f "$service"
        else
            docker compose logs --tail=100 "$service"
        fi
    else
        if [[ "$follow" == "follow" ]]; then
            docker compose logs -f
        else
            docker compose logs --tail=100
        fi
    fi
}

function show_status() {
    log_info "Network Status"
    log_info "=============="
    
    cd "$NETWORK_DIR"
    
    # Show container status
    docker compose ps
    
    echo ""
    log_info "Recent Block Numbers:"
    
    # Get block numbers from both clients
    local geth_block="N/A"
    local reth_block="N/A"
    
    if curl -s http://localhost:8545 > /dev/null 2>&1; then
        geth_block=$(curl -s -X POST http://localhost:8545 \
            -H "Content-Type: application/json" \
            --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' 2>/dev/null | grep -o '"result":"0x[^"]*"' | cut -d'"' -f4 || echo "N/A")
    fi
    
    if curl -s http://localhost:8547 > /dev/null 2>&1; then
        reth_block=$(curl -s -X POST http://localhost:8547 \
            -H "Content-Type: application/json" \
            --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' 2>/dev/null | grep -o '"result":"0x[^"]*"' | cut -d'"' -f4 || echo "N/A")
    fi
    
    echo "  op-geth: $geth_block"
    echo "  op-reth: $reth_block"
    
    if [[ "$geth_block" != "N/A" && "$reth_block" != "N/A" ]]; then
        if [[ "$geth_block" == "$reth_block" ]]; then
            log_info "✅ Clients are synchronized"
        else
            log_warn "⚠️  Clients are not synchronized"
        fi
    fi
}

function run_tests() {
    log_info "Running eth_simulateV1 tests..."
    
    cd "$NETWORK_DIR"
    
    if [[ -x "./scripts/test-eth-simulatev1.sh" ]]; then
        ./scripts/test-eth-simulatev1.sh
        local test_result=$?
        
        if [[ $test_result -eq 0 ]]; then
            log_info "✅ All tests passed"
        else
            log_error "❌ Some tests failed"
        fi
        
        return $test_result
    else
        log_error "Test script not found or not executable"
        return 1
    fi
}

function show_usage() {
    cat << EOF
Usage: $0 {start|stop|restart|clean|status|logs|test|setup}

Commands:
    setup      - Initial setup (create .env, generate keys)
    start      - Start the local network
    stop       - Stop the local network
    restart    - Restart the local network
    clean      - Stop and clean all network state
    status     - Show network status
    logs       - Show logs for all or specific service
    test       - Run eth_simulateV1 tests
    health     - Check network health
    help       - Show this help message

Examples:
    $0 setup                    # Initial setup
    $0 start                    # Start the network
    $0 status                   # Show network status
    $0 logs op-reth-2 follow    # Follow op-reth-2 logs
    $0 test                     # Run tests
    $0 stop                     # Stop the network
    $0 clean                    # Clean everything

Logs Commands:
    $0 logs                     # Show all logs (last 100 lines)
    $0 logs follow             # Follow all logs
    $0 logs op-geth-1          # Show op-geth-1 logs
    $0 logs op-reth-2 follow   # Follow op-reth-2 logs
EOF
}

# Main command dispatcher
case "${1:-help}" in
    setup)
        check_prerequisites
        setup_environment
        ;;
    start)
        cd "$NETWORK_DIR"
        if [[ ! -f ".env" ]]; then
            log_error "Network not set up. Run '$0 setup' first."
            exit 1
        fi
        start_network
        ;;
    stop)
        stop_network
        ;;
    restart)
        restart_network
        ;;
    clean)
        clean_network
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs "${2:-}" "${3:-}"
        ;;
    test)
        run_tests
        ;;
    health)
        check_network_health
        ;;
    help|--help)
        show_usage
        ;;
    *)
        log_error "Unknown command: $1"
        show_usage
        exit 1
        ;;
esac