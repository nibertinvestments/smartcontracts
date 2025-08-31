// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title SafeMath
 * @dev Gas-optimized math operations with overflow protection
 * @notice Uses unchecked blocks for gas efficiency where safe
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        unchecked {
            uint256 c = a + b;
            require(c >= a, "SafeMath: addition overflow");
            return c;
        }
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on underflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction underflow");
        unchecked {
            return a - b;
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        unchecked {
            if (a == 0) return 0;
            uint256 c = a * b;
            require(c / a == b, "SafeMath: multiplication overflow");
            return c;
        }
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on division by zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
        unchecked {
            return a / b;
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, reverting on division by zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: modulo by zero");
        unchecked {
            return a % b;
        }
    }

    /**
     * @dev Returns the minimum of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the maximum of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    /**
     * @dev Returns the average of two numbers. The result is rounded towards zero.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        unchecked {
            return (a & b) + ((a ^ b) >> 1);
        }
    }
}

/**
 * @title FixedPointMath
 * @dev Gas-optimized fixed-point arithmetic for DeFi calculations
 * @notice Uses 18 decimal places for precision
 */
library FixedPointMath {
    uint256 internal constant WAD = 1e18;
    uint256 internal constant HALF_WAD = 0.5e18;

    /**
     * @dev Multiplies two wad units, rounding half up
     */
    function mulWad(uint256 a, uint256 b) internal pure returns (uint256) {
        unchecked {
            if (a == 0 || b == 0) return 0;

            require(a <= type(uint256).max / WAD, "FixedPointMath: multiplication overflow");

            uint256 aWad = a * WAD;
            uint256 result;

            assembly {
                result := div(add(mul(aWad, b), HALF_WAD), WAD)
            }

            return result;
        }
    }

    /**
     * @dev Divides two wad units, rounding half up
     */
    function divWad(uint256 a, uint256 b) internal pure returns (uint256) {
        unchecked {
            require(b > 0, "FixedPointMath: division by zero");

            uint256 aScaled = a * WAD;

            assembly {
                aScaled := div(add(aScaled, div(b, 2)), b)
            }

            return aScaled;
        }
    }

    /**
     * @dev Calculates (a * b) / denominator with full precision
     */
    function mulDiv(uint256 a, uint256 b, uint256 denominator) internal pure returns (uint256) {
        unchecked {
            require(denominator > 0, "FixedPointMath: division by zero");

            uint256 prod0;
            uint256 prod1;

            assembly {
                let mm := mulmod(a, b, not(0))
                prod0 := mul(a, b)
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }

            if (prod1 == 0) {
                require(prod0 / denominator <= type(uint256).max, "FixedPointMath: multiplication overflow");
                return prod0 / denominator;
            }

            require(prod1 / denominator == 0, "FixedPointMath: multiplication overflow");
            return prod0 / denominator;
        }
    }

    /**
     * @dev Calculates square root using Babylonian method
     */
    function sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;

        uint256 z = (x + 1) / 2;
        uint256 y = x;

        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }

        return y;
    }

    /**
     * @dev Converts wad to ray (27 decimals)
     */
    function wadToRay(uint256 wad) internal pure returns (uint256) {
        return wad * 1e9;
    }

    /**
     * @dev Converts ray to wad (18 decimals)
     */
    function rayToWad(uint256 ray) internal pure returns (uint256) {
        return ray / 1e9;
    }
}

/**
 * @title BabylonianSqrt
 * @dev Gas-optimized square root calculation
 */
library BabylonianSqrt {
    /**
     * @dev Calculates sqrt(x) using Babylonian method
     */
    function sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        if (x <= 3) return 1;

        uint256 z = (x + 1) / 2;
        uint256 y = x;

        unchecked {
            while (z < y) {
                y = z;
                z = (x / z + z) / 2;
            }
        }

        return y;
    }
}

/**
 * @title TickMath
 * @dev Gas-optimized tick math for Uniswap V3 calculations
 */
library TickMath {
    int24 internal constant MIN_TICK = -887272;
    int24 internal constant MAX_TICK = 887272;

    /**
     * @dev Calculates sqrt(1.0001^tick) * 2^96
     */
    function getSqrtRatioAtTick(int24 tick) internal pure returns (uint160) {
        unchecked {
            uint256 absTick = tick < 0 ? uint256(-int256(tick)) : uint256(int256(tick));

            uint256 ratio = 0xfffcb933bd6fad37aa2d162d1a594001;
            if (absTick & 0x1 != 0) ratio = (ratio * 0xfff97272373d413259a46990580e213a) >> 128;
            if (absTick & 0x2 != 0) ratio = (ratio * 0xfff2e50f5f656932ef12357cf3c7fdcc) >> 128;
            if (absTick & 0x4 != 0) ratio = (ratio * 0xffe5caca7e10e4e61c3624eaa0941cd0) >> 128;
            if (absTick & 0x8 != 0) ratio = (ratio * 0xffcb9843d60f6159c9db58835c926644) >> 128;
            if (absTick & 0x10 != 0) ratio = (ratio * 0xff973b41fa98c081472e6896dfb254c0) >> 128;
            if (absTick & 0x20 != 0) ratio = (ratio * 0xff2ea16466c96a3843ec78b326b52861) >> 128;
            if (absTick & 0x40 != 0) ratio = (ratio * 0xfe5dee046a99a2a811c461f1969c3053) >> 128;
            if (absTick & 0x80 != 0) ratio = (ratio * 0xfcbe86c7900a88aedcffc83b479aa3a4) >> 128;
            if (absTick & 0x100 != 0) ratio = (ratio * 0xf987a7253ac413176f2b074cf7815e54) >> 128;
            if (absTick & 0x200 != 0) ratio = (ratio * 0xf3392b0822b70005940c7a398e4b70f3) >> 128;
            if (absTick & 0x400 != 0) ratio = (ratio * 0xe7159475a2c29b7443b29c7fa6a98979) >> 128;
            if (absTick & 0x800 != 0) ratio = (ratio * 0xd097f3bdfd2022b8845ad8f792aa5825) >> 128;
            if (absTick & 0x1000 != 0) ratio = (ratio * 0xa9f746462d870fdf8a65dc1f90e061e5) >> 128;
            if (absTick & 0x2000 != 0) ratio = (ratio * 0x70d869a156d2a1b890bb3df62baf32f7) >> 128;
            if (absTick & 0x4000 != 0) ratio = (ratio * 0x31be135f97d08fd981231505542fcfa6) >> 128;
            if (absTick & 0x8000 != 0) ratio = (ratio * 0x9aa508b5b7a84e1c677de54f3e99bc9) >> 128;
            if (absTick & 0x10000 != 0) ratio = (ratio * 0x5d6af8dedb81196699c329225ee604) >> 128;
            if (absTick & 0x20000 != 0) ratio = (ratio * 0x2216e584f5fa1ea926041bedfe98) >> 128;
            if (absTick & 0x40000 != 0) ratio = (ratio * 0x48a170391f7dc42444e8fa2) >> 128;

            if (tick > 0) ratio = type(uint256).max / ratio;

            assembly {
                ratio := shr(32, mul(ratio, 4294967296))
            }

            if (ratio % (1 << 32) > 0) ratio++;

            return uint160(ratio >> 32);
        }
    }

    /**
     * @dev Calculates tick from sqrt ratio
     */
    function getTickAtSqrtRatio(uint160 sqrtPriceX96) internal pure returns (int24) {
        unchecked {
            require(sqrtPriceX96 >= 4295048016 && sqrtPriceX96 < 79226673515401279992447579055, "TickMath: sqrt ratio out of bounds");

            uint256 ratio = uint256(sqrtPriceX96) << 32;

            uint256 r = ratio;
            uint256 msb = 0;

            assembly {
                let f := shl(1, gt(r, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF))
                msb := or(msb, f)
                r := shr(f, r)
            }
            assembly {
                let f := shl(2, gt(r, 0xFFFFFFFFFFFFFFFF))
                msb := or(msb, f)
                r := shr(f, r)
            }
            assembly {
                let f := shl(3, gt(r, 0xFFFFFFFF))
                msb := or(msb, f)
                r := shr(f, r)
            }

            if (msb >= 128) r = ratio >> (msb - 127);
            else r = ratio << (127 - msb);

            int256 log2 = (int256(msb) - 128) << 64;

            assembly {
                r := shr(127, mul(r, r))
                let f := shr(128, r)
                log2 := or(log2, shl(63, f))
                r := shr(f, r)
            }

            assembly {
                r := shr(127, mul(r, r))
                let f := shr(128, r)
                log2 := or(log2, shl(62, f))
                r := shr(f, r)
            }

            assembly {
                r := shr(127, mul(r, r))
                let f := shr(128, r)
                log2 := or(log2, shl(61, f))
                r := shr(f, r)
            }

            assembly {
                r := shr(127, mul(r, r))
                let f := shr(128, r)
                log2 := or(log2, shl(60, f))
                r := shr(f, r)
            }

            assembly {
                r := shr(127, mul(r, r))
                let f := shr(128, r)
                log2 := or(log2, shl(59, f))
                r := shr(f, r)
            }

            assembly {
                r := shr(127, mul(r, r))
                let f := shr(128, r)
                log2 := or(log2, shl(58, f))
                r := shr(f, r)
            }

            int256 logSqrt10001 = log2 * 255738958999603826347141;

            int24 tickLow = int24((logSqrt10001 - 3402992956809132418596140100660247210) >> 128);
            int24 tickHigh = int24((logSqrt10001 + 291339464771989622907027621153398088495) >> 128);

            return tickLow == tickHigh ? tickLow : getSqrtRatioAtTick(tickHigh) <= sqrtPriceX96 ? tickHigh : tickLow;
        }
    }
}
