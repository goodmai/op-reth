#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECRETS_DIR="${SCRIPT_DIR}/../secrets"

# Create validator keys for lighthouse
mkdir -p "$SECRETS_DIR/validator-keys-1"
mkdir -p "$SECRETS_DIR/validator-keys-2"

# Generate Lighthouse testnet files
echo "Generating testnet configuration..."

# Create genesis.ssz (minimal beacon chain genesis)
if command -v lighthouse &> /dev/null; then
    echo "Using lighthouse to generate genesis..."
    
    # Generate genesis specification
    cat > "$SECRETS_DIR/custom_config.yaml" << 'EOF'
# Minimal config
config_name: "custom"
preset_base: "minimal"

# Genesis
min_genesis_active_validator_count: 64
min_genesis_time: 0
genesis_delay: 0

# Fork configuration
altair_fork_epoch: 0
bellatrix_fork_epoch: 0
capella_fork_epoch: 0
deneb_fork_epoch: 0

# Time parameters
seconds_per_slot: 12
slots_per_epoch: 8

# Network
DEPOSIT_CONTRACT_ADDRESS: 0x4242424242424242424242424242424242424242
SECONDS_PER_ETH1_BLOCK: 12

# Validator
ETH1_FOLLOW_DISTANCE: 1
TARGET_AGGREGATORS_PER_COMMITTEE: 3
RANDOM_SUBNETS_PER_VALIDATOR: 0
EPOCHS_PER_RANDOM_SUBNET_SUBSCRIPTION: 0

# Deposit contract

# Network specific
BLS_WITHDRAWAL_PREFIX: 0x00
DOMAIN_APPLICATION_MASK: 0x00000001

# Transition
TERMINAL_TOTAL_DIFFICULTY: 0
TERMINAL_BLOCK_HASH: "0x0000000000000000000000000000000000000000000000000000000000000000"
TERMINAL_BLOCK_HASH_ACTIVATION_EPOCH: 18446744073709551615
EOF

    # Generate genesis.ssz
    lighthouse b spec_genesis \
        --spec minimal \
        --testnet-dir "$SCRIPT_DIR/../configs/consensus" \
        --deposit-contract-address 0x4242424242424242424242424242424242424242
        
    echo "Testnet configuration created in configs/consensus/"
else
    echo "Lighthouse not found, creating minimal config files..."
    mkdir -p "$SCRIPT_DIR/../configs/consensus"
    
    # Create a minimal spec file manually
    cat > "$SCRIPT_DIR/../configs/consensus/config.yaml" << 'EOF'
PRESET_BASE: 'minimal'
CONFIG_NAME: 'localnet'
MIN_GENESIS_ACTIVE_VALIDATOR_COUNT: 64
MIN_GENESIS_TIME: 0
GENESIS_DELAY: 0
SECONDS_PER_SLOT: 12
SLOTS_PER_EPOCH: 8
TERMINAL_TOTAL_DIFFICULTY: 0
DEPOSIT_CONTRACT_ADDRESS: 0x4242424242424242424242424242424242424242
EOF
fi

# Generate a new JWT secret if it doesn't exist
if [[ ! -f "$SECRETS_DIR/jwtsecret.hex" ]]; then
    echo "Generating new JWT secret..."
    openssl rand -hex 32 > "$SECRETS_DIR/jwtsecret.hex"
fi

echo "Key generation completed!"
echo "- JWT secret: secrets/jwtsecret.hex"
echo "- Consensus config: configs/consensus/"