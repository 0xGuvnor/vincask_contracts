# Include environment variables from .env file
-include .env

# Default Anvil private key for local development
ANVIL_KEY := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# Generate and save coverage report
coverage:; forge coverage --report debug > coverage-report.txt

# Deploy to Ethereum mainnet using hardware wallet (Trezor)
deploy-mainnet-hw:
	@forge script script/DeployVinCask.s.sol:DeployVinCask --rpc-url $(MAINNET_RPC_URL) --trezor --sender $(DEPLOYER_ADDRESS) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vv

# Deploy to Sepolia testnet using hardware wallet (Trezor)
deploy-sepolia-hw:
	@forge script script/DeployVinCask.s.sol:DeployVinCask --rpc-url $(SEPOLIA_RPC_URL) --trezor --sender $(DEPLOYER_ADDRESS) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vv

# Deploy to Sepolia testnet using private key
deploy-sepolia:
	@forge script script/DeployVinCask.s.sol:DeployVinCask --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vv

# Deploy to local Anvil network
deploy-anvil:
	@forge script script/DeployVinCask.s.sol:DeployVinCask --rpc-url $(ANVIL_RPC_URL) --private-key $(ANVIL_KEY) --broadcast -vv

# Run mainnet deployment simulation (no actual deployment)
deploy-mainnet-simulation:
	@forge script script/DeployVinCask.s.sol:DeployVinCask --rpc-url $(MAINNET_RPC_URL) --private-key $(PRIVATE_KEY) -vv