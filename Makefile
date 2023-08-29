-include .env

ANVIL_KEY := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

coverage:; forge coverage --report debug > coverage-report.txt

deploy-sepolia:
	@forge script script/DeployVincask.s.sol:DeployVincask --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vv

deploy-goerli:
	@forge script script/DeployVincask.s.sol:DeployVincask --rpc-url $(GOERLI_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vv

deploy-anvil:
	@forge script script/DeployVincask.s.sol:DeployVincask --rpc-url $(ANVIL_RPC_URL) --private-key $(ANVIL_KEY) --broadcast -vv