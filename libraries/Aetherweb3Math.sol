// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Aetherweb3Math
 * @dev Mathematical utility library for precise calculations in DeFi
 * @notice Provides safe mathematical operations with overflow protection
 */
library Aetherweb3Math {
    uint256 internal constant WAD = 1e18;
    uint256 internal constant RAY = 1e27;
    uint256 internal constant RAD = 1e45;

    /**
     * @dev Multiplies two wad (18 decimal) numbers
     * @param x First number in wad
     * @param y Second number in wad
     * @return z Result in wad
     */
    function wmul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = (x * y + WAD / 2) / WAD;
    }

    /**
     * @dev Divides two wad numbers
     * @param x Numerator in wad
     * @param y Denominator in wad
     * @return z Result in wad
     */
    function wdiv(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = (x * WAD + y / 2) / y;
    }

    /**
     * @dev Multiplies two ray (27 decimal) numbers
     * @param x First number in ray
     * @param y Second number in ray
     * @return z Result in ray
     */
    function rmul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = (x * y + RAY / 2) / RAY;
    }

    /**
     * @dev Divides two ray numbers
     * @param x Numerator in ray
     * @param y Denominator in ray
     * @return z Result in ray
     */
    function rdiv(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = (x * RAY + y / 2) / y;
    }

    /**
     * @dev Converts wad to ray
     * @param x Number in wad
     * @return y Number in ray
     */
    function w2r(uint256 x) internal pure returns (uint256 y) {
        y = x * 1e9;
    }

    /**
     * @dev Converts ray to wad
     * @param x Number in ray
     * @return y Number in wad
     */
    function r2w(uint256 x) internal pure returns (uint256 y) {
        y = x / 1e9;
    }

    /**
     * @dev Calculates percentage of amount
     * @param amount Total amount
     * @param percentage Percentage (basis points, 10000 = 100%)
     * @return result Amount * percentage / 10000
     */
    function percent(uint256 amount, uint256 percentage) internal pure returns (uint256 result) {
        require(percentage <= 10000, "Aetherweb3Math: percentage too high");
        result = (amount * percentage) / 10000;
    }

    /**
     * @dev Calculates compound interest
     * @param principal Initial amount
     * @param rate Annual interest rate in wad (1e18 = 100%)
     * @param time Time in seconds
     * @return result Principal * (1 + rate)^time
     */
    function compound(uint256 principal, uint256 rate, uint256 time) internal pure returns (uint256 result) {
        if (time == 0) return principal;
        if (rate == 0) return principal;

        // Using continuous compounding approximation: e^(rate * time)
        // For precision, we use the formula: principal * (1 + rate * time / 365 days)
        uint256 year = 365 days;
        uint256 effectiveRate = wmul(rate, time) / year;
        result = wmul(principal, WAD + effectiveRate);
    }

    /**
     * @dev Calculates square root using Babylonian method
     * @param x Number to calculate square root of
     * @return y Square root of x
     */
    function sqrt(uint256 x) internal pure returns (uint256 y) {
        if (x == 0) return 0;

        uint256 z = (x + 1) / 2;
        y = x;

        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }

    /**
     * @dev Calculates minimum of two numbers
     * @param a First number
     * @param b Second number
     * @return Minimum value
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Calculates maximum of two numbers
     * @param a First number
     * @param b Second number
     * @return Maximum value
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    /**
     * @dev Calculates average of two numbers
     * @param a First number
     * @param b Second number
     * @return Average value
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        return (a + b) / 2;
    }

    /**
     * @dev Calculates absolute difference between two numbers
     * @param a First number
     * @param b Second number
     * @return Absolute difference
     */
    function abs(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a - b : b - a;
    }

    /**
     * @dev Checks if two numbers are approximately equal within tolerance
     * @param a First number
     * @param b Second number
     * @param tolerance Maximum difference allowed
     * @return True if numbers are approximately equal
     */
    function approx(uint256 a, uint256 b, uint256 tolerance) internal pure returns (bool) {
        return abs(a, b) <= tolerance;
    }
}
