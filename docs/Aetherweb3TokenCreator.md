# Aetherweb3 Token Creator

A comprehensive token creation platform for the Aetherweb3 DeFi ecosystem that allows users to create highly customizable ERC20 tokens on any EVM-compatible blockchain.

## 🌟 Features

### Token Types
- **Standard ERC20**: Basic token with standard functionality
- **Burnable**: Tokens that can be burned to reduce supply
- **Mintable**: Tokens that can be minted by owner
- **Pausable**: Tokens that can be paused/unpaused by owner
- **Capped**: Tokens with maximum supply limit
- **Taxable**: Tokens with transaction taxes
- **Reflection**: Tokens with automatic reward distribution
- **Governance**: Tokens with voting capabilities
- **Full Featured**: All features combined

### Advanced Features
- **Custom Decimals**: Support for any decimal precision (0-18)
- **Supply Management**: Initial supply and maximum supply control
- **Tax System**: Configurable buy/sell/transfer taxes
- **Reflection Rewards**: Automatic reward distribution to holders
- **Governance Integration**: Built-in voting and delegation
- **Flash Minting**: Support for flash loan operations
- **Permit Functionality**: Gasless approvals via EIP-2612

## 💰 Fee Structure

- **Creation Fee**: 0.005 ETH/WETH per token creation
- **Fee Recipient**: `0xD10AA6E922a4F1804db6Ad3f0960Ed3dc116DD57`
- **Fee Exemptions**: Available for ecosystem partners
- **Network Support**: Works on all EVM-compatible chains

## 🚀 Quick Start

### 1. Environment Setup

```bash
# Copy environment template
cp .env.example .env

# Edit .env with your configuration
nano .env
```

Required environment variables:
```bash
# Your private key (NEVER commit to version control)
PRIVATE_KEY=0x...

# Fee recipient (pre-configured)
FEE_RECIPIENT=0xD10AA6E922a4F1804db6Ad3f0960Ed3dc116DD57

# Network RPC URLs
MAINNET_RPC_URL=https://mainnet.infura.io/v3/YOUR_PROJECT_ID
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR_PROJECT_ID
```

### 2. Deploy Token Creator

```bash
# Install dependencies
npm install

# Deploy to Sepolia testnet
npx hardhat run scripts/deploy-token-creator.js --network sepolia

# Deploy to mainnet
npx hardhat run scripts/deploy-token-creator.js --network mainnet
```

### 3. Create Your First Token

```javascript
// Using ethers.js
const tokenCreator = await ethers.getContractAt(
  "Aetherweb3TokenCreator",
  "DEPLOYED_CONTRACT_ADDRESS"
);

// Create a standard token
const tx = await tokenCreator.createStandardToken(
  "My Token",      // name
  "MTK",          // symbol
  ethers.utils.parseEther("1000000"), // 1M tokens
  18,             // decimals
  {
    value: ethers.utils.parseEther("0.005") // creation fee
  }
);

await tx.wait();
console.log("Token created successfully!");
```

## 📋 Token Creation Examples

### Standard Token
```javascript
const tokenAddress = await tokenCreator.createStandardToken(
  "My Standard Token",
  "MST",
  ethers.utils.parseEther("1000000"),
  18
);
```

### Full Featured Token
```javascript
// Define tax configuration
const taxConfig = {
  buyTax: 300,        // 3% buy tax
  sellTax: 500,       // 5% sell tax
  transferTax: 100,   // 1% transfer tax
  taxWallet: "0x...", // tax collection wallet
  taxOnBuys: true,
  taxOnSells: true,
  taxOnTransfers: true
};

// Define reflection configuration
const reflectionConfig = {
  reflectionFee: 200,     // 2% reflection fee
  rewardToken: ethers.constants.AddressZero, // use same token
  autoClaim: true,
  minTokensForClaim: ethers.utils.parseEther("1000")
};

// Create full featured token
const tokenAddress = await tokenCreator.createToken({
  name: "My Full Featured Token",
  symbol: "MFFT",
  initialSupply: ethers.utils.parseEther("10000000"),
  decimals: 18,
  maxSupply: ethers.utils.parseEther("100000000"),
  owner: deployer.address,
  features: {
    burnable: true,
    mintable: true,
    pausable: true,
    capped: true,
    taxable: true,
    reflection: true,
    governance: true,
    flashMint: true,
    permit: true
  },
  taxConfig: taxConfig,
  reflectionConfig: reflectionConfig,
  salt: ethers.utils.randomBytes(32)
}, {
  value: ethers.utils.parseEther("0.005")
});
```

### Custom Token with Specific Features
```javascript
const tokenAddress = await tokenCreator.createToken({
  name: "My Custom Token",
  symbol: "MCT",
  initialSupply: ethers.utils.parseEther("5000000"),
  decimals: 9,  // Custom decimals
  maxSupply: ethers.utils.parseEther("50000000"),
  owner: deployer.address,
  features: {
    burnable: true,
    mintable: false,
    pausable: true,
    capped: true,
    taxable: false,
    reflection: false,
    governance: false,
    flashMint: false,
    permit: true
  },
  taxConfig: {
    buyTax: 0,
    sellTax: 0,
    transferTax: 0,
    taxWallet: ethers.constants.AddressZero,
    taxOnBuys: false,
    taxOnSells: false,
    taxOnTransfers: false
  },
  reflectionConfig: {
    reflectionFee: 0,
    rewardToken: ethers.constants.AddressZero,
    autoClaim: false,
    minTokensForClaim: 0
  },
  salt: ethers.utils.randomBytes(32)
}, {
  value: ethers.utils.parseEther("0.005")
});
```

## 🔧 Advanced Configuration

### Tax System
Configure transaction taxes for different operations:

```javascript
const taxConfig = {
  buyTax: 300,        // 3% on buys
  sellTax: 500,       // 5% on sells
  transferTax: 100,   // 1% on transfers
  taxWallet: "0x...", // tax collection address
  taxOnBuys: true,
  taxOnSells: true,
  taxOnTransfers: true
};
```

### Reflection Rewards
Set up automatic reward distribution:

```javascript
const reflectionConfig = {
  reflectionFee: 200,     // 2% reflection fee
  rewardToken: "0x...",   // reward token address (0x0 for same token)
  autoClaim: true,        // automatic claiming
  minTokensForClaim: ethers.utils.parseEther("1000") // minimum balance
};
```

### Governance Features
Enable voting and governance capabilities:

```javascript
const governanceFeatures = {
  governance: true,      // enable governance
  permit: true          // enable gasless approvals
};
```

## 🌐 Multi-Chain Deployment

### Supported Networks

The Token Creator works on all EVM-compatible chains:

- **Ethereum Mainnet**
- **Polygon (Matic)**
- **Binance Smart Chain**
- **Arbitrum**
- **Optimism**
- **Avalanche**
- **Fantom**
- **And many more...**

### Network Configuration

Update `hardhat.config.js` for your target networks:

```javascript
module.exports = {
  networks: {
    mainnet: {
      url: process.env.MAINNET_RPC_URL,
      accounts: [process.env.PRIVATE_KEY]
    },
    polygon: {
      url: "https://polygon-rpc.com",
      accounts: [process.env.PRIVATE_KEY]
    },
    bsc: {
      url: "https://bsc-dataseed.binance.org",
      accounts: [process.env.PRIVATE_KEY]
    }
  }
};
```

### Cross-Chain Deployment

```bash
# Deploy to Polygon
npx hardhat run scripts/deploy-token-creator.js --network polygon

# Deploy to BSC
npx hardhat run scripts/deploy-token-creator.js --network bsc

# Deploy to Arbitrum
npx hardhat run scripts/deploy-token-creator.js --network arbitrum
```

## 🔍 Contract Verification

### Automatic Verification

The deployment script automatically attempts to verify contracts on supported networks.

### Manual Verification

If automatic verification fails:

```bash
npx hardhat verify --network mainnet CONTRACT_ADDRESS "FEE_RECIPIENT_ADDRESS"
```

## 📊 Token Management

### View Created Tokens

```javascript
// Get all tokens created by an address
const tokens = await tokenCreator.getCreatorTokens(userAddress);

// Get creation statistics
const [totalCreated, totalFees] = await tokenCreator.getCreationStats();
```

### Verify Token

```javascript
// Verify a token (only creator can verify)
await tokenCreator.verifyToken(tokenAddress);
```

### Update Fee Recipient

```javascript
// Update fee recipient (only owner)
await tokenCreator.updateFeeRecipient(newFeeRecipient);
```

## 🛡️ Security Features

### Built-in Security
- **Reentrancy Protection**: Using OpenZeppelin's ReentrancyGuard
- **Access Control**: Owner-only functions with Ownable
- **Input Validation**: Comprehensive parameter validation
- **Emergency Controls**: Pause/unpause functionality

### Fee Management
- **Transparent Fees**: Fixed 0.005 ETH/WETH creation fee
- **Fee Exemptions**: Configurable exemptions for partners
- **Fee Withdrawal**: Owner can withdraw accumulated fees

## 🧪 Testing

### Run Tests

```bash
# Run all tests
npx hardhat test

# Run specific test file
npx hardhat test test/Aetherweb3TokenCreator.test.js

# Run tests with gas reporting
npx hardhat test --gas
```

### Test Coverage

```bash
# Generate coverage report
npx hardhat coverage
```

## 📈 Analytics & Monitoring

### Contract Analytics

The Token Creator provides comprehensive analytics:

- **Total Tokens Created**: Track ecosystem growth
- **Fee Collection**: Monitor revenue
- **Network Usage**: Deployment statistics
- **Token Verification**: Quality control

### Integration with The Graph

For advanced analytics, integrate with The Graph protocol:

```graphql
{
  tokenCreators {
    id
    feeRecipient
    totalTokensCreated
    totalFeesCollected
  }
  tokens {
    id
    name
    symbol
    creator
    creationTime
    verified
  }
}
```

## 🔗 Ecosystem Integration

### Aetherweb3 Libraries

The Token Creator integrates with all Aetherweb3 libraries:

- **Aetherweb3Math**: For precise calculations
- **Aetherweb3Safety**: For security features
- **Aetherweb3Governance**: For governance tokens
- **Aetherweb3Staking**: For staking integrations
- **Aetherweb3AMM**: For liquidity features

### Third-Party Integrations

- **Uniswap V3**: Automatic liquidity provision
- **Chainlink**: Price feeds for dynamic fees
- **The Graph**: Subgraph integration
- **IPFS**: Metadata storage

## 🚨 Troubleshooting

### Common Issues

1. **Insufficient Funds**
   ```
   Error: Insufficient fee
   Solution: Ensure you send exactly 0.005 ETH/WETH
   ```

2. **Network Congestion**
   ```
   Error: Transaction failed
   Solution: Increase gas price or wait for network to clear
   ```

3. **Contract Verification Failed**
   ```
   Error: Verification failed
   Solution: Check API keys and try manual verification
   ```

### Support

- **Documentation**: Check this README and inline code comments
- **Discord**: Join the Aetherweb3 community
- **GitHub Issues**: Report bugs and request features
- **Email**: Contact the development team

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🤝 Contributing

We welcome contributions to the Aetherweb3 Token Creator!

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

### Development Guidelines

- Follow Solidity style guide
- Write comprehensive tests
- Update documentation
- Ensure gas efficiency
- Maintain backward compatibility

## 🔮 Future Enhancements

### Planned Features

- **Cross-Chain Token Creation**: Create tokens on multiple chains simultaneously
- **Token Templates**: Pre-built templates for common use cases
- **Advanced Tax Systems**: Dynamic tax rates based on market conditions
- **Token Migration**: Migrate tokens between different standards
- **DAO Integration**: Automatic DAO creation with token deployment
- **NFT Integration**: Hybrid token/NFT creation
- **Layer 2 Support**: Optimized deployment on Layer 2 networks

### Roadmap

- **Q4 2025**: Cross-chain functionality
- **Q1 2026**: Advanced tax systems
- **Q2 2026**: DAO integration
- **Q3 2026**: Layer 2 optimizations

---

**Built for the Aetherweb3 DeFi Ecosystem** 🏗️

*Empowering creators with the most advanced token creation platform on any blockchain.*
