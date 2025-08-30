# Aetherweb3 Token Creator

A comprehensive token creation platform for the Aetherweb3 DeFi ecosystem that allows users to create highly customizable ERC20 tokens on any EVM-compatible blockchain.

## 🌟 Features

### Token Customization
- **Multiple Token Types**: Standard ERC20, Burnable, Mintable, Pausable, Capped, Taxable, Reflection, Governance, Flash Mint, and Full-Featured tokens
- **Advanced Features**:
  - Transaction taxes with customizable rates
  - Reflection rewards distribution
  - Governance voting capabilities
  - Supply caps and burning mechanisms
  - Flash minting support
  - Permit functionality for gasless approvals

### Security & Compliance
- Built on OpenZeppelin battle-tested contracts
- Reentrancy protection
- Emergency pause functionality
- Input validation and overflow protection
- Comprehensive access controls

### Multi-Chain Support
- Deploy on any EVM-compatible blockchain
- Automatic contract verification
- Network-specific optimizations
- Cross-chain compatibility

## 🚀 Quick Start

### Prerequisites
- Node.js 16+
- npm or yarn
- Hardhat
- Private key with sufficient funds

### Installation

1. **Clone the repository**
```bash
git clone https://github.com/nibertinvestments/smartcontracts.git
cd smartcontracts
```

2. **Install dependencies**
```bash
npm install
```

3. **Configure environment**
```bash
cp .env.example .env
```

Edit `.env` with your configuration:
```env
# Aetherweb3 Ecosystem Configuration
FEE_RECIPIENT=0xD10AA6E922a4F1804db6Ad3f0960Ed3dc116DD57
CREATION_FEE=5000000000000000

# Network RPC URLs
MAINNET_RPC_URL=https://mainnet.infura.io/v3/YOUR_INFURA_KEY
GOERLI_RPC_URL=https://goerli.infura.io/v3/YOUR_INFURA_KEY
POLYGON_RPC_URL=https://polygon-rpc.com
BSC_RPC_URL=https://bsc-dataseed.binance.org

# Your private key (NEVER commit this!)
PRIVATE_KEY=your_private_key_here

# Block explorer API keys for verification
ETHERSCAN_API_KEY=your_etherscan_api_key
POLYGONSCAN_API_KEY=your_polygonscan_api_key
BSCSCAN_API_KEY=your_bscscan_api_key
```

4. **Compile contracts**
```bash
npm run compile
```

5. **Deploy to your desired network**
```bash
# Deploy to Ethereum Mainnet
npm run deploy:mainnet

# Deploy to Polygon
npm run deploy:polygon

# Deploy to BSC
npm run deploy:bsc

# Deploy to testnet
npm run deploy:sepolia
```

## 💰 Fee Structure

- **Creation Fee**: 0.005 ETH/WETH (configurable via `.env`)
- **Fee Recipient**: `0xD10AA6E922a4F1804db6Ad3f0960Ed3dc116DD57`
- **Fee Exemption**: Available for ecosystem contracts

## 🛠️ Token Creation

### Basic Token Creation

```javascript
const { ethers } = require("ethers");

// Connect to deployed contract
const tokenCreator = new ethers.Contract(
  "DEPLOYED_CONTRACT_ADDRESS",
  Aetherweb3TokenCreatorABI,
  signer
);

// Create a standard token
const tx = await tokenCreator.createStandardToken(
  "My Token",      // name
  "MTK",          // symbol
  "1000000",      // initial supply (without decimals)
  18,             // decimals
  {
    value: ethers.utils.parseEther("0.005") // creation fee
  }
);
```

### Advanced Token Creation

```javascript
// Create a full-featured token with taxes and reflection
const tokenParams = {
  name: "Advanced Token",
  symbol: "ADV",
  initialSupply: "1000000000000000000000000", // 1M tokens with 18 decimals
  decimals: 18,
  maxSupply: "10000000000000000000000000", // 10M max supply
  owner: signer.address,
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
  taxConfig: {
    buyTax: 300,      // 3% buy tax
    sellTax: 500,     // 5% sell tax
    transferTax: 100, // 1% transfer tax
    taxWallet: "0x...", // tax collection wallet
    taxOnBuys: true,
    taxOnSells: true,
    taxOnTransfers: true
  },
  reflectionConfig: {
    reflectionFee: 200, // 2% reflection fee
    rewardToken: "0x...", // reward token address
    autoClaim: true,
    minTokensForClaim: "1000000000000000000" // 1 token minimum
  }
};

const tx = await tokenCreator.createToken(tokenParams, {
  value: ethers.utils.parseEther("0.005")
});
```

## 📋 Token Types

### 1. Standard Token
- Basic ERC20 functionality
- Transfer, approve, transferFrom
- No additional features

### 2. Burnable Token
- Can burn tokens to reduce supply
- `burn()` and `burnFrom()` functions

### 3. Mintable Token
- Owner can mint new tokens
- Controlled supply expansion
- `mint()` function

### 4. Pausable Token
- Can pause all transfers
- Emergency stop functionality
- `pause()` and `unpause()` functions

### 5. Capped Token
- Maximum supply limit
- Prevents over-minting
- Configurable cap

### 6. Taxable Token
- Automatic tax collection on transactions
- Configurable tax rates
- Separate tax wallet

### 7. Reflection Token
- Automatic reward distribution
- Reflection fees on transactions
- Claimable rewards

### 8. Governance Token
- Voting capabilities
- Proposal creation
- Delegation support

### 9. Flash Mint Token
- Flash minting support
- Temporary token creation
- MEV protection

### 10. Full-Featured Token
- All features combined
- Maximum customization
- Advanced functionality

## 🔧 Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `FEE_RECIPIENT` | Address to receive creation fees | `0xD10AA6E922a4F1804db6Ad3f0960Ed3dc116DD57` |
| `CREATION_FEE` | Fee amount in wei | `5000000000000000` (0.005 ETH) |
| `PRIVATE_KEY` | Deployer private key | Required for deployment |
| `ETHERSCAN_API_KEY` | Etherscan API key | Required for verification |

### Network Configuration

The contract supports deployment on any EVM-compatible network:

- **Ethereum Mainnet**
- **Polygon**
- **BSC**
- **Arbitrum**
- **Optimism**
- **Avalanche**
- **Fantom**
- **And many more...**

## 🧪 Testing

```bash
# Run all tests
npm test

# Run tests with gas reporting
npm run test:gas

# Run coverage analysis
npm run test:coverage
```

## 📊 Contract Verification

The deployment script automatically verifies contracts on supported block explorers:

- **Etherscan** (Ethereum)
- **PolygonScan** (Polygon)
- **BscScan** (BSC)
- **Arbiscan** (Arbitrum)
- **Optimistic Etherscan** (Optimism)

## 🔒 Security

### Built-in Security Features
- **Reentrancy Protection**: Prevents reentrancy attacks
- **Access Control**: Role-based permissions
- **Input Validation**: Comprehensive parameter validation
- **Emergency Pause**: Circuit breaker functionality
- **Overflow Protection**: Safe math operations

### Best Practices
- Always test on testnet first
- Verify contracts after deployment
- Use multisig for admin functions
- Monitor contract activity
- Keep private keys secure

## 📈 Analytics & Monitoring

### Contract Analytics
- Total tokens created
- Fee collection tracking
- Network utilization
- Creator statistics

### Monitoring
- Transaction monitoring
- Fee collection alerts
- Network status tracking
- Performance metrics

## 🤝 Integration

### Frontend Integration
```javascript
import { ethers } from 'ethers';
import Aetherweb3TokenCreatorABI from './Aetherweb3TokenCreatorABI.json';

const provider = new ethers.providers.Web3Provider(window.ethereum);
const signer = provider.getSigner();

const tokenCreator = new ethers.Contract(
  CONTRACT_ADDRESS,
  Aetherweb3TokenCreatorABI,
  signer
);
```

### Backend Integration
```javascript
const { ethers } = require('ethers');

const tokenCreator = new ethers.Contract(
  CONTRACT_ADDRESS,
  Aetherweb3TokenCreatorABI,
  wallet
);

// Listen for token creation events
tokenCreator.on('TokenCreated', (tokenAddress, creator, name, symbol, supply, tokenType) => {
  console.log(`New token created: ${name} (${symbol}) at ${tokenAddress}`);
});
```

## 📚 API Reference

### Core Functions

#### `createToken(TokenParams params)`
Creates a new token with custom parameters.

#### `createStandardToken(string name, string symbol, uint256 supply, uint8 decimals)`
Creates a basic ERC20 token.

#### `updateFeeRecipient(address newRecipient)`
Updates the fee recipient address (owner only).

#### `updateCreationFee(uint256 newFee)`
Updates the creation fee (owner only).

### View Functions

#### `getCreatorTokens(address creator)`
Returns all tokens created by an address.

#### `getTokenInfo(address tokenAddress)`
Returns detailed information about a token.

#### `creationFee()`
Returns the current creation fee.

## 🐛 Troubleshooting

### Common Issues

1. **Insufficient Funds**
   - Ensure deployer has enough ETH for gas + creation fee
   - Check network-specific requirements

2. **Contract Verification Failed**
   - Ensure correct API keys in `.env`
   - Wait a few minutes after deployment
   - Check network compatibility

3. **Transaction Failed**
   - Verify all parameters are correct
   - Check contract balance for fees
   - Ensure network is not congested

### Support
- Check the [GitHub Issues](https://github.com/nibertinvestments/smartcontracts/issues)
- Review the documentation
- Join the community discussions

## 📄 License

MIT License - see [LICENSE](../LICENSE) file for details.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## 🔗 Links

- [GitHub Repository](https://github.com/nibertinvestments/smartcontracts)
- [Documentation](./docs/)
- [Aetherweb3 Ecosystem](https://aetherweb3.com)

---

**Built for the Aetherweb3 DeFi Ecosystem** 🏗️

*Empowering creators with customizable token solutions on every blockchain.*
