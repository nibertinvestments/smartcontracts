# Aetherweb3 Libraries

## Overview

The Aetherweb3 ecosystem utilizes specialized libraries for common operations, mathematical calculations, and utility functions. These libraries are designed for gas efficiency, type safety, and reusability across the protocol.

## SafeCast

### Library Overview

SafeCast provides safe casting functions between different integer types with overflow/underflow protection. It prevents common vulnerabilities related to type casting in Solidity.

### Functions

```solidity
library SafeCast {
    function toUint128(uint256 x) internal pure returns (uint128);
    function toUint96(uint256 x) internal pure returns (uint96);
    function toUint64(uint256 x) internal pure returns (uint64);
    function toUint32(uint256 x) internal pure returns (uint32);
    function toUint16(uint256 x) internal pure returns (uint16);
    function toUint8(uint256 x) internal pure returns (uint8);

    function toInt128(int256 x) internal pure returns (int128);
    function toInt96(int256 x) internal pure returns (int96);
    function toInt64(int256 x) internal pure returns (int64);
    function toInt32(int256 x) internal pure returns (int32);
    function toInt16(int256 x) internal pure returns (int16);
    function toInt8(int256 x) internal pure returns (int8);
}
```

### Usage Examples

```solidity
import "./libraries/SafeCast.sol";

contract MyContract {
    using SafeCast for uint256;
    using SafeCast for int256;

    function safeCastExample(uint256 largeNumber) external pure returns (uint128) {
        // Safe cast with overflow protection
        return largeNumber.toUint128();
    }

    function safeIntCast(int256 signedNumber) external pure returns (int96) {
        // Safe cast for signed integers
        return signedNumber.toInt96();
    }
}
```

### Security Benefits

- **Overflow Protection**: Prevents silent overflows during casting
- **Explicit Errors**: Reverts with clear error messages on overflow
- **Type Safety**: Ensures proper type conversions
- **Gas Efficient**: Minimal gas overhead for safe operations

## TransferHelper

### Library Overview

TransferHelper provides safe token transfer functions with proper error handling and return value checking. It prevents common issues with ERC20 transfers that don't return boolean values.

### Functions

```solidity
library TransferHelper {
    function safeTransfer(address token, address to, uint256 value) internal;
    function safeTransferFrom(address token, address from, address to, uint256 value) internal;
    function safeTransferETH(address to, uint256 value) internal;
}
```

### Usage Examples

```solidity
import "./libraries/TransferHelper.sol";

contract MyContract {
    using TransferHelper for address;

    function transferTokens(address token, address recipient, uint256 amount) external {
        // Safe ERC20 transfer
        token.safeTransfer(recipient, amount);
    }

    function transferFromUser(address token, address user, uint256 amount) external {
        // Safe transfer from user
        token.safeTransferFrom(user, address(this), amount);
    }

    function refundETH(address payable recipient, uint256 amount) external {
        // Safe ETH transfer
        recipient.safeTransferETH(amount);
    }
}
```

### Security Benefits

- **Return Value Checking**: Verifies transfer success
- **Error Propagation**: Proper error handling and messages
- **Reentrancy Protection**: Safe transfer patterns
- **ETH Transfer Safety**: Handles ETH transfers securely

## TickMath

### Library Overview

TickMath provides mathematical functions for tick calculations in the AMM. It handles conversions between prices, square root prices, and tick indices with proper precision.

### Key Functions

```solidity
library TickMath {
    function getSqrtRatioAtTick(int24 tick) internal pure returns (uint160);
    function getTickAtSqrtRatio(uint160 sqrtPriceX96) internal pure returns (int24);
    function getPriceAtTick(int24 tick) internal pure returns (uint256);
    function getTickAtPrice(uint256 price) internal pure returns (int24);
}
```

### Usage Examples

```solidity
import "./libraries/TickMath.sol";

contract PriceCalculator {
    using TickMath for int24;
    using TickMath for uint160;

    function calculatePriceFromTick(int24 tick) external pure returns (uint256) {
        return tick.getPriceAtTick();
    }

    function calculateTickFromSqrtPrice(uint160 sqrtPriceX96) external pure returns (int24) {
        return sqrtPriceX96.getTickAtSqrtRatio();
    }
}
```

### Mathematical Properties

- **Precision**: Handles 96-bit fixed point arithmetic
- **Range**: Supports wide price ranges efficiently
- **Accuracy**: Minimizes rounding errors in calculations
- **Gas Optimized**: Efficient mathematical operations

## LiquidityMath

### Library Overview

LiquidityMath provides functions for liquidity calculations in AMM pools. It handles additions and subtractions of liquidity with proper overflow protection.

### Functions

```solidity
library LiquidityMath {
    function addDelta(uint128 x, int128 y) internal pure returns (uint128);
    function addLiquidity(uint128 x, uint128 y) internal pure returns (uint128);
    function removeLiquidity(uint128 x, uint128 y) internal pure returns (uint128);
}
```

### Usage Examples

```solidity
import "./libraries/LiquidityMath.sol";

contract LiquidityManager {
    using LiquidityMath for uint128;

    function addToPosition(uint128 currentLiquidity, uint128 additionalLiquidity)
        external
        pure
        returns (uint128)
    {
        return currentLiquidity.addLiquidity(additionalLiquidity);
    }

    function updateLiquidity(uint128 currentLiquidity, int128 delta)
        external
        pure
        returns (uint128)
    {
        return currentLiquidity.addDelta(delta);
    }
}
```

## SwapMath

### Library Overview

SwapMath handles the mathematical calculations for token swaps in AMM pools. It computes swap results, fees, and price impacts with high precision.

### Key Functions

```solidity
library SwapMath {
    function computeSwapStep(
        uint160 sqrtRatioCurrentX96,
        uint160 sqrtRatioTargetX96,
        uint128 liquidity,
        uint256 amountRemaining,
        uint24 feePips
    ) internal pure returns (
        uint160 sqrtRatioNextX96,
        uint256 amountIn,
        uint256 amountOut,
        uint256 feeAmount
    );
}
```

### Usage Examples

```solidity
import "./libraries/SwapMath.sol";

contract SwapCalculator {
    using SwapMath for uint160;

    function calculateSwap(
        uint160 currentSqrtPrice,
        uint160 targetSqrtPrice,
        uint128 liquidity,
        uint256 amountIn,
        uint24 fee
    ) external pure returns (uint256 amountOut, uint256 feeAmount) {
        (
            ,
            ,
            uint256 out,
            uint256 fee
        ) = currentSqrtPrice.computeSwapStep(
            targetSqrtPrice,
            liquidity,
            amountIn,
            fee
        );

        return (out, fee);
    }
}
```

## FixedPoint96

### Library Overview

FixedPoint96 provides constants and utilities for 96-bit fixed point arithmetic used in price calculations.

### Constants

```solidity
library FixedPoint96 {
    uint8 internal constant RESOLUTION = 96;
    uint256 internal constant Q96 = 2**96;
}
```

### Usage Examples

```solidity
import "./libraries/FixedPoint96.sol";

contract PriceMath {
    using FixedPoint96 for uint256;

    function scalePrice(uint256 price) external pure returns (uint256) {
        return price * FixedPoint96.Q96;
    }

    function descalePrice(uint256 scaledPrice) external pure returns (uint256) {
        return scaledPrice / FixedPoint96.Q96;
    }
}
```

## FullMath

### Library Overview

FullMath provides full precision arithmetic operations for large numbers, preventing overflow in complex calculations.

### Functions

```solidity
library FullMath {
    function mulDiv(
        uint256 a,
        uint256 b,
        uint256 denominator
    ) internal pure returns (uint256 result);

    function mulDivRoundingUp(
        uint256 a,
        uint256 b,
        uint256 denominator
    ) internal pure returns (uint256 result);
}
```

### Usage Examples

```solidity
import "./libraries/FullMath.sol";

contract PreciseMath {
    using FullMath for uint256;

    function calculateFee(uint256 amount, uint256 feeBips) external pure returns (uint256) {
        // Calculate fee with full precision
        return amount.mulDiv(feeBips, 10000);
    }

    function calculateShare(uint256 total, uint256 portion, uint256 totalShares)
        external
        pure
        returns (uint256)
    {
        // Calculate proportional share
        return total.mulDiv(portion, totalShares);
    }
}
```

## Library Integration

### Importing Libraries

```solidity
// Import all libraries
import "./libraries/SafeCast.sol";
import "./libraries/TransferHelper.sol";
import "./libraries/TickMath.sol";
import "./libraries/LiquidityMath.sol";
import "./libraries/SwapMath.sol";
import "./libraries/FixedPoint96.sol";
import "./libraries/FullMath.sol";

// Use in contract
contract Aetherweb3Pool {
    using SafeCast for uint256;
    using TransferHelper for address;
    using TickMath for int24;
    using LiquidityMath for uint128;
    using SwapMath for uint160;
    using FullMath for uint256;

    // Contract implementation using libraries
}
```

### Best Practices

1. **Using Statements**: Use `using` statements for clean syntax
2. **Type Safety**: Leverage library functions for safe operations
3. **Testing**: Test library functions thoroughly
4. **Documentation**: Document complex mathematical operations
5. **Gas Optimization**: Choose appropriate precision levels

## License

These libraries are licensed under the MIT License.
