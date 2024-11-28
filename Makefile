-include .env

ANVIL_KEY := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

coverage:; forge coverage --report debug > coverage-report.txt

deploy-mainnet-hw:
	@forge script script/DeployVinCask.s.sol:DeployVinCask --rpc-url $(MAINNET_RPC_URL) --trezor --sender $(DEPLOYER_ADDRESS) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vv

deploy-sepolia-hw:
	@forge script script/DeployVinCask.s.sol:DeployVinCask --rpc-url $(SEPOLIA_RPC_URL) --trezor --sender $(DEPLOYER_ADDRESS) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vv

deploy-sepolia:
	@forge script script/DeployVinCask.s.sol:DeployVinCask --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vv

deploy-goerli:
	@forge script script/DeployVinCask.s.sol:DeployVinCask --rpc-url $(GOERLI_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vv

deploy-anvil:
	@forge script script/DeployVinCask.s.sol:DeployVinCask --rpc-url $(ANVIL_RPC_URL) --private-key $(ANVIL_KEY) --broadcast -vv

deploy-mainnet-simulation:
	@forge script script/DeployVinCask.s.sol:DeployVinCask --rpc-url $(MAINNET_RPC_URL) --private-key $(PRIVATE_KEY) -vv