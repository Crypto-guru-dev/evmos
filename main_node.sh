#!/bin/bash

KEYS[0]="EvtFoundation"

CHAINID="evt_8848-1"
MONIKER="evtteam"
# Remember to change to other types of keyring like 'file' in-case exposing to outside world,
# otherwise your balance will be wiped quickly
# The keyring test does not require private key to steal tokens from you
KEYRING="os"
KEYALGO="eth_secp256k1"
LOGLEVEL="info"
# Set dedicated home directory for the evtd instance
HOMEDIR="$HOME/.evtd"
# to trace evm
#TRACE="--trace"
TRACE=""

# Path variables
CONFIG=$HOMEDIR/config/config.toml
GENESIS=$HOMEDIR/config/genesis.json
TMP_GENESIS=$HOMEDIR/config/tmp_genesis.json

# validate dependencies are installed
command -v jq >/dev/null 2>&1 || {
	echo >&2 "jq not installed. More info: https://stedolan.github.io/jq/download/"
	exit 1
}

# used to exit on first error (any non-zero exit code)
set -e

# Reinstall daemon
make install

# User prompt if an existing local node configuration is found.
if [ -d "$HOMEDIR" ]; then
	printf "\nAn existing folder at '%s' was found. You can choose to delete this folder and start a new local node with new keys from genesis. When declined, the existing local node is started. \n" "$HOMEDIR"
	echo "Overwrite the existing configuration and start a new local node? [y/n]"
	read -r overwrite
else
	overwrite="Y"
fi

# Setup local node if overwrite is set to Yes, otherwise skip setup
if [[ $overwrite == "y" || $overwrite == "Y" ]]; then
	# Remove the previous folder
	rm -rf "$HOMEDIR"

	# Set client config
	evtd config keyring-backend $KEYRING --home "$HOMEDIR"
	evtd config chain-id $CHAINID --home "$HOMEDIR"

	# If keys exist they should be deleted
	for KEY in "${KEYS[@]}"; do
		evtd keys add $KEY --keyring-backend $KEYRING --algo $KEYALGO --home "$HOMEDIR" 
	done

	# Set moniker and chain-id for Evmos (Moniker can be anything, chain-id must be an integer)
	evtd init $MONIKER -o --chain-id $CHAINID --home "$HOMEDIR"

	# Change parameter token denominations to evt
	jq '.app_state["staking"]["params"]["bond_denom"]="aevt"' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"
	jq '.app_state["crisis"]["constant_fee"]["denom"]="aevt"' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"
	jq '.app_state["gov"]["deposit_params"]["min_deposit"][0]["denom"]="aevt"' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"
	jq '.app_state["gov"]["deposit_params"]["min_deposit"][0]["amount"]="1000000000000000000000"' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"
	jq '.app_state["evm"]["params"]["evm_denom"]="aevt"' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"
	jq '.app_state["inflation"]["params"]["mint_denom"]="aevt"' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"
	jq '.app_state["feemarket"]["block_gas"]="20000000"' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"
	jq '.app_state["feemarket"]["params"]["min_gas_price"]="0.001"' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"
	jq '.consensus_params["block"]["max_gas"]="20000000000"' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"

	if [[ $1 == "pending" ]]; then
		if [[ "$OSTYPE" == "darwin"* ]]; then
			sed -i '' 's/timeout_propose = "3s"/timeout_propose = "30s"/g' "$CONFIG"
			sed -i '' 's/timeout_propose_delta = "500ms"/timeout_propose_delta = "5s"/g' "$CONFIG"
			sed -i '' 's/timeout_prevote = "1s"/timeout_prevote = "10s"/g' "$CONFIG"
			sed -i '' 's/timeout_prevote_delta = "500ms"/timeout_prevote_delta = "5s"/g' "$CONFIG"
			sed -i '' 's/timeout_precommit = "1s"/timeout_precommit = "10s"/g' "$CONFIG"
			sed -i '' 's/timeout_precommit_delta = "500ms"/timeout_precommit_delta = "5s"/g' "$CONFIG"
			sed -i '' 's/timeout_commit = "3s"/timeout_commit = "150s"/g' "$CONFIG"
			sed -i '' 's/timeout_broadcast_tx_commit = "10s"/timeout_broadcast_tx_commit = "150s"/g' "$CONFIG"
		else
			sed -i 's/timeout_propose = "3s"/timeout_propose = "30s"/g' "$CONFIG"
			sed -i 's/timeout_propose_delta = "500ms"/timeout_propose_delta = "5s"/g' "$CONFIG"
			sed -i 's/timeout_prevote = "1s"/timeout_prevote = "10s"/g' "$CONFIG"
			sed -i 's/timeout_prevote_delta = "500ms"/timeout_prevote_delta = "5s"/g' "$CONFIG"
			sed -i 's/timeout_precommit = "1s"/timeout_precommit = "10s"/g' "$CONFIG"
			sed -i 's/timeout_precommit_delta = "500ms"/timeout_precommit_delta = "5s"/g' "$CONFIG"
			sed -i 's/timeout_commit = "3s"/timeout_commit = "150s"/g' "$CONFIG"
			sed -i 's/timeout_broadcast_tx_commit = "10s"/timeout_broadcast_tx_commit = "150s"/g' "$CONFIG"
		fi
	fi

	# sed -i 's/timeout_commit = "5s"/timeout_commit = "2s"/g' "$CONFIG"
	sed -i 's/cors_allowed_origins = \[\]/cors_allowed_origins = \["*"\]/g' "$CONFIG"
	sed -i 's/laddr = "tcp:\/\/127.0.0.1:26657"/laddr = "tcp:\/\/0.0.0.0:26657"/g' "$CONFIG"

	sed -i 's/address = "127.0.0.1:8545"/address = "0.0.0.0:8545"/g' ~/.evtd/config/app.toml
	sed -i 's/ws-address = "127.0.0.1:8546"/ws-address = "0.0.0.0:8546"/g' ~/.evtd/config/app.toml
	
	sed -i '/\[api\]/,+3 s/enable = false/enable = true/' ~/.evtd/config/app.toml
	sed -i 's/swagger = false/swagger = true/g' ~/.evtd/config/app.toml
	sed -i 's/enabled-unsafe-cors = false/enabled-unsafe-cors = true/g'  ~/.evtd/config/app.toml
	# sed -i 's/enable-indexer = false/enable-indexer = true/g' ~/.evtd/config/app.toml
	sed -i 's/api = "eth,net,web3"/api = "eth,txpool,personal,net,debug,web3,pubsub,trace"/g' ~/.evtd/config/app.toml
	sed -i 's/pruning = "default"/pruning = "nothing"/g' ~/.evtd/config/app.toml

	# Allocate genesis accounts (cosmos formatted addresses)
	
	evtd add-genesis-account ${KEYS[0]} 10000000000000000000000000aevt --keyring-backend $KEYRING --home "$HOMEDIR"


	# bc is required to add these big numbers
	total_supply=$(echo "10000000000000000000000000" | bc)
	jq -r --arg total_supply "$total_supply" '.app_state["bank"]["supply"][0]["amount"]=$total_supply' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"


	# Sign genesis transaction
	evtd gentx ${KEYS[0]} 1000000000000000000000aevt --keyring-backend $KEYRING --chain-id $CHAINID --home "$HOMEDIR"  --min-self-delegation 10000 --fees 20000aevt



	# Collect genesis tx
	evtd collect-gentxs --home "$HOMEDIR"

	# Run this to ensure everything worked and that the genesis file is setup correctly
	evtd validate-genesis --home "$HOMEDIR"

	if [[ $1 == "pending" ]]; then
		echo "pending mode is on, please wait for the first block committed."
	fi
fi

#evtd start --pruning=nothing "$TRACE"  --minimum-gas-prices=0.0001aevt --rpc.laddr tcp://0.0.0.0:26657 --log_level $LOGLEVEL --json-rpc.api eth,txpool,personal,net,debug,web3 --api.enable --home "$HOMEDIR"

# evtd start --pruning=nothing "$TRACE"  --rpc.laddr tcp://0.0.0.0:26657 --log_level $LOGLEVEL --json-rpc.api eth,txpool,personal,net,debug,web3 --api.enable --home "$HOMEDIR"