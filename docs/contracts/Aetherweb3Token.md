# Aetherweb3Token

## Overview

Aetherweb3Token is the primary ERC20 token for the Aetherweb3 DeFi ecosystem. It serves as the base currency for liquidity provision, trading fees, and governance within the Aetherweb3 AMM (Automated Market Maker) protocol.

## Features

- **ERC20 Standard Compliance**: Full implementation of the ERC20 token standard
- **OpenZeppelin Security**: Built on audited OpenZeppelin contracts for maximum security
- **Fixed Supply**: Pre-mined supply with no additional minting capabilities
- **Transfer Restrictions**: Optional transfer restrictions for regulatory compliance
- **Gas Optimized**: Efficient implementation for reduced gas costs

## Contract Details

### Constructor Parameters

```solidity
constructor(
    string memory name_,
    string memory symbol_,
    uint256 totalSupply_,
    address owner_
)
```

- `name_`: Token name (e.g., "Aetherweb3 Token")
- `symbol_`: Token symbol (e.g., "AETH")
- `totalSupply_`: Total token supply (in wei)
- `owner_`: Initial owner address

### Key Functions

#### Public Functions

- `transfer(address to, uint256 amount)`: Transfer tokens to another address
- `transferFrom(address from, address to, uint256 amount)`: Transfer tokens on behalf of another address
- `approve(address spender, uint256 amount)`: Approve spender to transfer tokens
- `increaseAllowance(address spender, uint256 addedValue)`: Increase allowance for spender
- `decreaseAllowance(address spender, uint256 subtractedValue)`: Decrease allowance for spender

#### View Functions

- `name()`: Returns the token name
- `symbol()`: Returns the token symbol
- `decimals()`: Returns the number of decimals (18)
- `totalSupply()`: Returns the total token supply
- `balanceOf(address account)`: Returns the balance of an account
- `allowance(address owner, address spender)`: Returns the allowance for spender

#### Owner Functions

- `pause()`: Pause all token transfers (emergency stop)
- `unpause()`: Resume token transfers
- `transferOwnership(address newOwner)`: Transfer contract ownership

## Usage Examples

### Basic Token Operations

```solidity
// Transfer tokens
aetherToken.transfer(recipient, amount);

// Approve spending
aetherToken.approve(spender, amount);

// Transfer from approved account
aetherToken.transferFrom(owner, recipient, amount);
```

### Integration with Aetherweb3 AMM

```solidity
// Add liquidity to Aetherweb3 pool
aetherToken.approve(routerAddress, liquidityAmount);
router.addLiquidity(tokenA, tokenB, amountA, amountB, ...);
```

## Deployment

### Prerequisites

- Hardhat development environment
- OpenZeppelin contracts library
- Sufficient ETH for deployment

### Deployment Script

```javascript
const { ethers } = require("hardhat");

async function main() {
    const [deployer] = await ethers.getSigners();

    console.log("Deploying Aetherweb3Token...");

    const Aetherweb3Token = await ethers.getContractFactory("Aetherweb3Token");
    const token = await Aetherweb3Token.deploy(
        "Aetherweb3 Token",
        "AETH",
        ethers.utils.parseEther("1000000"), // 1M tokens
        deployer.address
    );

    await token.deployed();
    console.log("Aetherweb3Token deployed to:", token.address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
```

### Verification

After deployment, verify the contract on Etherscan:

```bash
npx hardhat verify --network mainnet DEPLOYED_CONTRACT_ADDRESS "Aetherweb3 Token" "AETH" "1000000000000000000000000" "0x..."
```

## Security Considerations

- **Ownership Transfer**: Use timelock for ownership transfers in production
- **Pause Functionality**: Implement emergency pause mechanisms
- **Access Control**: Restrict sensitive functions to authorized addresses
- **Audit**: Contract has been audited for security vulnerabilities

## Integration Guide

### With Aetherweb3Router

```solidity
// Approve router for token spending
token.approve(router.address, amount);

// Perform swap through router
router.swapExactTokensForTokens(amountIn, amountOutMin, path, to, deadline);
```

### With Aetherweb3Factory

```solidity
// Create new trading pair
factory.createPool(tokenA.address, tokenB.address);

// Get pool address
address poolAddress = factory.getPool(tokenA.address, tokenB.address);
```

## Events

- `Transfer(address indexed from, address indexed to, uint256 value)`
- `Approval(address indexed owner, address indexed spender, uint256 value)`
- `Paused(address account)`
- `Unpaused(address account)`
- `OwnershipTransferred(address indexed previousOwner, address indexed newOwner)`

## Gas Optimization

- Uses OpenZeppelin's optimized ERC20 implementation
- Minimal storage operations
- Efficient approval mechanisms
- Batch transfer support through multicall

## Testing

Run the test suite:

```bash
npx hardhat test test/Aetherweb3Token.test.js
```

### Test Coverage

- Token transfers and approvals
- Pause/unpause functionality
- Ownership transfer
- Integration with AMM contracts
- Gas usage optimization

## License

This contract is licensed under the MIT License.
