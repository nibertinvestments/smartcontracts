# Aetherweb3 Smart Contracts

[![Solidity](https://img.shields.io/badge/Solidity-^0.8.0-blue.svg)](https://soliditylang.org/)
[![Hardhat](https://img.shields.io/badge/Hardhat-2.19.0-yellow.svg)](https://hardhat.org/)
[![OpenZeppelin](https://img.shields.io/badge/OpenZeppelin-5.0.0-green.svg)](https://openzeppelin.com/)

A comprehensive DeFi ecosystem featuring ERC20 tokens and automated market maker (AMM) functionality for the Aetherweb3 blockchain platform.

## 🌟 Features

### Aetherweb3Token (ERC20)
- Standard ERC20 implementation with OpenZeppelin
- 18 decimal places
- Mintable by deployer
- Full ERC20 compliance

### Aetherweb3Router (V3 Router)
- **Swap Functionality**: Exact input/output swaps with single and multi-hop support
- **Liquidity Management**: Add/remove liquidity from pools
- **Multicall Support**: Batch multiple operations in a single transaction
- **WETH Integration**: Native ETH support through WETH wrapping/unwrapping
- **Deadline Protection**: Prevent stale transaction execution
- **Gas Optimized**: Efficient routing and execution

### Aetherweb3Oracle (Price Oracle)
- **Multi-Source Feeds**: Aggregate price data from multiple sources
- **Confidence Intervals**: Statistical confidence in price feeds
- **Access Controls**: Owner-controlled price updates
- **Timestamp Tracking**: Historical price data with timestamps
- **Emergency Controls**: Circuit breaker functionality

## 📋 Prerequisites

- [Node.js](https://nodejs.org/) >= 16.0.0
- [npm](https://www.npmjs.com/) or [yarn](https://yarnpkg.com/)
- [Git](https://git-scm.com/)

## 🚀 Installation

1. **Clone the repository:**
```bash
git clone https://github.com/nibertinvestments/smartcontracts.git
cd smartcontracts
```

2. **Install dependencies:**
```bash
npm install
```

3. **Compile contracts:**
```bash
npx hardhat compile
```

## 🔧 Configuration

### Environment Setup

Create a `.env` file in the root directory:

```env
# Network Configuration
MAINNET_RPC_URL=https://mainnet.infura.io/v3/YOUR_INFURA_KEY
TESTNET_RPC_URL=https://sepolia.infura.io/v3/YOUR_INFURA_KEY

# Private Key (NEVER commit this to version control)
PRIVATE_KEY=0x...

# Etherscan API Key (for contract verification)
ETHERSCAN_API_KEY=YOUR_ETHERSCAN_API_KEY
```

### Hardhat Configuration

The `hardhat.config.js` is pre-configured for:
- Solidity ^0.8.0 compilation
- Multiple network support
- Gas optimization
- Contract verification

## 📦 Deployment

### Local Development

1. **Start local Hardhat network:**
```bash
npx hardhat node
```

2. **Deploy to local network:**
```bash
npx hardhat run scripts/deploy.js --network localhost
```

### Testnet Deployment

1. **Deploy to Sepolia testnet:**
```bash
npx hardhat run scripts/deploy.js --network sepolia
```

2. **Deploy to other testnets:**
```bash
npx hardhat run scripts/deploy.js --network <network-name>
```

### Mainnet Deployment

⚠️ **WARNING**: Mainnet deployment requires careful verification and testing.

```bash
npx hardhat run scripts/deploy.js --network mainnet
```

### Contract Verification

After deployment, verify contracts on Etherscan:

```bash
npx hardhat verify --network <network> <CONTRACT_ADDRESS> <CONSTRUCTOR_ARGS>
```

## 🏗️ Contract Architecture

```
contracts/
├── Aetherweb3Token.sol          # ERC20 Token Implementation
├── Aetherweb3Factory.sol        # Pool Factory Contract
├── Aetherweb3PoolDeployer.sol   # Pool Deployment Handler
├── Aetherweb3Pool.sol           # Basic Pool Implementation
├── Aetherweb3Router.sol         # V3 Router for Swaps & Liquidity
├── Aetherweb3Oracle.sol         # Price Oracle Contract
├── libraries/
│   ├── TransferHelper.sol       # Safe Token Transfer Library
│   └── SafeCast.sol            # Safe Type Casting Library
└── interfaces/
    ├── IAetherweb3Factory.sol
    ├── IAetherweb3PoolDeployer.sol
    ├── IAetherweb3Router.sol
    ├── IAetherweb3Oracle.sol
    ├── IERC20Minimal.sol
    └── pool/
        ├── IAetherweb3PoolImmutables.sol
        ├── IAetherweb3PoolState.sol
        ├── IAetherweb3PoolDerivedState.sol
        ├── IAetherweb3PoolActions.sol
        ├── IAetherweb3PoolOwnerActions.sol
        └── IAetherweb3PoolEvents.sol
```

### Deployment Flow

1. **Deploy PoolDeployer** → Returns `POOL_DEPLOYER_ADDRESS`
2. **Deploy Factory** with `POOL_DEPLOYER_ADDRESS` → Returns `FACTORY_ADDRESS`
3. **Set Factory Address** in PoolDeployer
4. **Deploy Oracle** → Returns `ORACLE_ADDRESS`
5. **Deploy Router** with `FACTORY_ADDRESS` and `WETH_ADDRESS` → Returns `ROUTER_ADDRESS`
6. **Create Pools** using Factory
7. **Configure Oracle** with price feeds and access controls

## 📖 Usage Examples

### Creating a Pool

```javascript
const { ethers } = require("hardhat");

async function createPool() {
  const factory = await ethers.getContractAt("Aetherweb3Factory", FACTORY_ADDRESS);

  // Create a pool between two tokens with 0.3% fee
  const poolAddress = await factory.createPool(
    tokenA.address,
    tokenB.address,
    3000  // 0.3% fee
  );

  console.log("Pool created at:", poolAddress);
}
```

### Minting Tokens

```javascript
const token = await ethers.getContractAt("Aetherweb3Token", TOKEN_ADDRESS);

// Mint 1000 tokens (assuming 18 decimals)
await token.mint(recipientAddress, ethers.utils.parseEther("1000"));
```

### Enabling New Fee Tiers

```javascript
const factory = await ethers.getContractAt("Aetherweb3Factory", FACTORY_ADDRESS);

// Enable 0.25% fee tier with 50 tick spacing
await factory.enableFeeAmount(2500, 50);
```

### Router Swaps

```javascript
const router = await ethers.getContractAt("Aetherweb3Router", ROUTER_ADDRESS);

// Exact input single swap
const params = {
  tokenIn: tokenA.address,
  tokenOut: tokenB.address,
  fee: 3000, // 0.3%
  recipient: recipientAddress,
  deadline: Math.floor(Date.now() / 1000) + 3600, // 1 hour
  amountIn: ethers.utils.parseEther("1"),
  amountOutMinimum: ethers.utils.parseEther("0.9"),
  sqrtPriceLimitX96: 0
};

const amountOut = await router.exactInputSingle(params);
```

### Multicall Operations

```javascript
const router = await ethers.getContractAt("Aetherweb3Router", ROUTER_ADDRESS);

// Batch multiple operations
const calls = [
  router.interface.encodeFunctionData("exactInputSingle", [swapParams1]),
  router.interface.encodeFunctionData("exactInputSingle", [swapParams2]),
  router.interface.encodeFunctionData("unwrapWETH9", [0, recipientAddress])
];

const results = await router.multicall(calls);
```

## 🧪 Testing

### Run Tests

```bash
# Run all tests
npx hardhat test

# Run specific test file
npx hardhat test test/Aetherweb3Factory.test.js

# Run tests with gas reporting
npx hardhat test --gas
```

### Test Coverage

```bash
npx hardhat coverage
```

### Test Structure

```
test/
├── Aetherweb3Token.test.js      # ERC20 token tests
├── Aetherweb3Factory.test.js    # Factory functionality tests
└── shared/
    └── utilities.js             # Test utilities
```

## 📊 Contract Addresses

### Mainnet
- **Aetherweb3Factory**: `0x...`
- **Aetherweb3Token**: `0x...`

### Testnet (Sepolia)
- **Aetherweb3Factory**: `0x...`
- **Aetherweb3Token**: `0x...`

## 🔒 Security

### Audits
- [Audit Report 1](link-to-audit)
- [Audit Report 2](link-to-audit)

### Security Considerations
- Contracts use OpenZeppelin battle-tested libraries
- Reentrancy protection implemented
- Access controls in place
- Emergency pause functionality available

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Commit changes: `git commit -m 'Add amazing feature'`
4. Push to branch: `git push origin feature/amazing-feature`
5. Open a Pull Request

### Development Guidelines
- Follow Solidity style guide
- Write comprehensive tests
- Update documentation
- Ensure gas efficiency

## 📄 License

This project is licensed under the GPL-2.0-or-later License - see the [LICENSE](LICENSE) file for details.

## 🙋 Support

- **Documentation**: [Aetherweb3 Docs](https://docs.aetherweb3.com)
- **Discord**: [Join our community](https://discord.gg/aetherweb3)
- **Twitter**: [@Aetherweb3](https://twitter.com/aetherweb3)
- **Email**: support@aetherweb3.com

## 🔄 Version History

### v1.0.0 (Current)
- Initial release
- ERC20 token implementation
- PoolFactory with V3-style functionality
- Basic pool deployment system

### Upcoming Features
- [ ] Full V3 concentrated liquidity implementation
- [ ] Staking and farming contracts
- [ ] Governance system
- [ ] Cross-chain functionality

---

**Built with ❤️ for the Aetherweb3 ecosystem**
