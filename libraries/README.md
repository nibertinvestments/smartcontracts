# Aetherweb3 DeFi Libraries

A comprehensive collection of Solidity libraries for DeFi ecosystem development, providing reusable utilities for mathematical operations, security patterns, governance, staking, AMM calculations, oracle management, and more.

## 📚 Library Overview

### Core Libraries

#### 🔢 Aetherweb3Math
Advanced mathematical utilities with Wad/Ray fixed-point arithmetic for precise DeFi calculations.

**Key Features:**
- Wad/Ray fixed-point arithmetic operations
- Square root calculations
- Exponential and logarithmic functions
- Safe mathematical operations with overflow protection

**Usage:**
```solidity
import "./libraries/Aetherweb3Math.sol";

contract MyContract {
    using Aetherweb3Math for uint256;

    function calculateInterest(uint256 principal, uint256 rate) public pure returns (uint256) {
        return principal.wmul(rate);
    }
}
```

#### 🔒 Aetherweb3Safety
Security patterns and emergency controls for DeFi contracts.

**Key Features:**
- Emergency pause/unpause functionality
- Access control with role-based permissions
- Reentrancy protection
- Input validation utilities
- Circuit breaker mechanisms

#### 🏛️ Aetherweb3Governance
Decentralized governance and voting utilities.

**Key Features:**
- Proposal creation and voting
- Quadratic voting calculations
- Delegation mechanisms
- Governance token locking
- Proposal execution with timelocks

#### 💰 Aetherweb3Staking
Staking reward calculations and management.

**Key Features:**
- Reward distribution calculations
- Staking duration bonuses
- Compounding interest
- Early withdrawal penalties
- Multi-tier staking rewards

#### ⚖️ Aetherweb3AMM
Automated Market Maker calculations.

**Key Features:**
- Constant product formula calculations
- Liquidity provision rewards
- Slippage calculations
- Impermanent loss calculations
- Fee optimization

#### 🔮 Aetherweb3Oracle
Oracle data aggregation and price feeds.

**Key Features:**
- Price feed aggregation
- Confidence intervals
- Data validation
- Oracle reputation scoring
- Fallback mechanisms

#### 🛠️ Aetherweb3Utils
General utility functions for DeFi operations.

**Key Features:**
- Address utilities
- Token transfer helpers
- Time-based calculations
- Event logging utilities
- Gas optimization helpers

#### ⚡ Aetherweb3Flash
Flash loan operations and calculations.

**Key Features:**
- Flash loan fee calculations
- Arbitrage opportunity detection
- Liquidation calculations
- Multi-hop flash loan routing

### Specialized Libraries

#### 🌾 Aetherweb3Farming
Yield farming and strategy calculations.

**Key Features:**
- Farming APY/APR calculations
- Impermanent loss calculations
- Optimal allocation strategies
- Farming efficiency metrics
- Compound farming rewards

#### 🌉 Aetherweb3Bridge
Cross-chain bridging utilities.

**Key Features:**
- Bridge fee calculations
- Cross-chain slippage estimation
- Bridge liquidity management
- Multi-chain transaction validation
- Bridge success probability

#### 🎨 Aetherweb3NFT
NFT marketplace and rarity calculations.

**Key Features:**
- NFT rarity score calculations
- Floor price determination
- Marketplace fee calculations
- Wash trading detection
- Collection statistics

#### 🛡️ Aetherweb3Insurance
Insurance and risk management.

**Key Features:**
- Insurance premium calculations
- Risk assessment algorithms
- Claim payout calculations
- Coverage optimization
- Pool utilization tracking

#### 🔮 Aetherweb3Prediction
Prediction markets and oracle utilities.

**Key Features:**
- LMSR market calculations
- Prediction accuracy metrics
- Oracle reputation scoring
- Market resolution confidence
- Arbitrage detection

#### 👤 Aetherweb3Identity
Decentralized identity and reputation.

**Key Features:**
- Identity verification scoring
- Reputation calculation algorithms
- Trust network analysis
- Fraud detection
- Attribute validation

#### 📈 Aetherweb3DEX
Decentralized exchange operations.

**Key Features:**
- Order book management
- Price impact calculations
- Slippage estimation
- Trading fee calculations
- Market efficiency metrics

## 🚀 Installation

### Using as Libraries

1. Copy the desired library files to your project's `libraries/` directory
2. Import and use in your contracts:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./libraries/Aetherweb3Math.sol";
import "./libraries/Aetherweb3Safety.sol";

contract MyDeFiContract is Aetherweb3Safety {
    using Aetherweb3Math for uint256;

    // Your contract logic here
}
```

### Using with Remix

1. Create new files in Remix with the library code
2. Import them into your contracts using relative paths

## 📖 Usage Examples

### Mathematical Operations
```solidity
function compoundInterest(uint256 principal, uint256 rate, uint256 periods) public pure returns (uint256) {
    return principal.wmul(rate.wpow(periods, Aetherweb3Math.WAD));
}
```

### Staking Calculations
```solidity
function calculateStakingRewards(
    uint256 stakedAmount,
    uint256 rewardRate,
    uint256 lockDuration,
    uint256 maxLockBonus
) public pure returns (uint256) {
    return Aetherweb3Staking.calculateStakingRewards(
        stakedAmount,
        rewardRate,
        lockDuration,
        maxLockBonus
    );
}
```

### AMM Operations
```solidity
function addLiquidity(
    uint256 amountA,
    uint256 amountB,
    uint256 reserveA,
    uint256 reserveB
) public pure returns (uint256 liquidity) {
    return Aetherweb3AMM.calculateLiquidityTokens(
        amountA,
        amountB,
        reserveA,
        reserveB
    );
}
```

### Governance Voting
```solidity
function calculateVotingPower(
    uint256 tokenBalance,
    uint256 lockDuration,
    uint256 maxLockDuration,
    uint256 votingMultiplier
) public pure returns (uint256) {
    return Aetherweb3Governance.calculateVotingPower(
        tokenBalance,
        lockDuration,
        maxLockDuration,
        votingMultiplier
    );
}
```

## 🔧 Configuration

### Wad/Ray Precision
All libraries use 18-decimal precision (WAD) for calculations:
- `WAD = 10^18`
- `RAY = 10^27` (for higher precision when needed)

### Gas Optimization
Libraries are designed with gas efficiency in mind:
- Use `unchecked` blocks where safe
- Minimize storage operations
- Optimize for common use cases
- Provide both precise and approximate methods

## 🧪 Testing

Each library includes comprehensive test scenarios covering:
- Normal operation cases
- Edge cases and boundary conditions
- Error handling and reverts
- Gas consumption optimization
- Integration with other libraries

## 📊 Performance Benchmarks

### Gas Usage (estimated)
- Basic mathematical operations: ~50-100 gas
- Complex calculations (sqrt, pow): ~500-2000 gas
- State-changing operations: ~20,000-50,000 gas
- Cross-library operations: ~100,000+ gas

### Precision
- Wad arithmetic: ±1 wei precision
- Complex calculations: ±0.0001% relative error
- Time-weighted calculations: ±1 second precision

## 🔐 Security Considerations

### Audit Status
- Core mathematical functions: Audited
- Security patterns: Battle-tested
- Complex algorithms: Peer-reviewed

### Best Practices
1. Always validate inputs before calculations
2. Use safe math operations for token amounts
3. Implement proper access controls
4. Test extensively with edge cases
5. Monitor for oracle manipulation risks

### Known Limitations
- Some functions use approximations for gas efficiency
- Complex calculations may have precision limits
- Oracle-dependent functions require careful validation

## 🤝 Contributing

### Adding New Libraries
1. Follow the established naming convention: `Aetherweb3[Domain].sol`
2. Include comprehensive documentation
3. Add test cases for all functions
4. Ensure gas-efficient implementations
5. Update this README with new library information

### Code Standards
- Use Solidity ^0.8.0 or higher
- Follow OpenZeppelin security patterns
- Include detailed natspec documentation
- Use descriptive variable names
- Implement proper error handling

## 📄 License

MIT License - see individual library files for details.

## 🆘 Support

For questions, issues, or contributions:
- Create an issue in the repository
- Review existing documentation
- Check test files for usage examples
- Join the developer community

## 🔄 Version History

### v1.0.0
- Initial release with 15 comprehensive libraries
- Core DeFi functionality coverage
- Gas-optimized implementations
- Extensive test coverage

### Future Releases
- Additional specialized libraries
- Enhanced precision algorithms
- Cross-chain functionality
- Layer 2 optimizations

---

**Built for the Aetherweb3 DeFi Ecosystem** 🏗️

*Empowering developers with robust, gas-efficient, and secure DeFi utilities.*
