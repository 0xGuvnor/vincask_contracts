# 🥃 VinCask NFT

VinCask NFTs combine the world of digital art with topshelf whisky. A fusion of creativity and connoisseurship, each NFT is not just a pierce of art; it's your ticket to a bottle of fine premium whisky.

## 🚀 Getting Started

### Requirements

- [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
  - You'll know you did it right if you can run `git --version` and you see a response like `git version x.x.x`
- [foundry](https://getfoundry.sh/)
  - You'll know you did it right if you can run `forge --version` and you see a response like `forge 0.2.0 (816e00b 2023-03-16T00:05:26.396218Z)`

### Quickstart

```bash
git clone https://github.com/0xGuvnor/vincask_contracts.git
cd vincask_contracts
forge build
```

### Deploy

#### Deploying to Mainnet/Testnet

- Create a .env file with the following variables:
  - `PRIVATE_KEY`
  - `GOERLI_RPC_URL`
  - `SEPOLIA_RPC_URL`
  - `ANVIL_RPC_URL`
  - `ETHERSCAN_API_KEY`

#### Ethereum Goerli

```bash
make deploy-goerli
```

#### Ethereum Sepolia

```bash
make deploy-sepolia
```

#### Local Anvil node

This will spin up a local Anvil node, which needs to already be running in another terminal before deploying.

```bash
make deploy-anvil
```

## 🧪 Testing

```bash
forge test
```

### Test Coverage

```bash
forge coverage
```

### Test Coverage Report

```bash
make coverage
```
