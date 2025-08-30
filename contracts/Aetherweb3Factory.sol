// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import './interfaces/IAetherweb3Factory.sol';
import "./interfaces/IAetherweb3PoolDeployer.sol";

/// @title Canonical Aetherweb3 factory
/// @notice Deploys Aetherweb3 pools and manages ownership and control over pool protocol fees
contract Aetherweb3Factory is IAetherweb3Factory {
    /// @inheritdoc IAetherweb3Factory
    address public override owner;

    address public immutable poolDeployer;

    /// @inheritdoc IAetherweb3Factory
    mapping(uint24 => int24) public override feeAmountTickSpacing;
    /// @inheritdoc IAetherweb3Factory
    mapping(address => mapping(address => mapping(uint24 => address))) public override getPool;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(address _poolDeployer) {
        poolDeployer = _poolDeployer;
        owner = msg.sender;
        emit OwnerChanged(address(0), msg.sender);

        feeAmountTickSpacing[500] = 10;
        emit FeeAmountEnabled(500, 10);
        feeAmountTickSpacing[3000] = 60;
        emit FeeAmountEnabled(3000, 60);
        feeAmountTickSpacing[10000] = 200;
        emit FeeAmountEnabled(10000, 200);
    }

    /// @inheritdoc IAetherweb3Factory
    function createPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external override returns (address pool) {
        require(tokenA != tokenB);
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0));
        int24 tickSpacing = feeAmountTickSpacing[fee];
        require(tickSpacing != 0);
        require(getPool[token0][token1][fee] == address(0));
        pool = IAetherweb3PoolDeployer(poolDeployer).deploy(address(this), token0, token1, fee, tickSpacing);
        getPool[token0][token1][fee] = pool;
        // populate mapping in the reverse direction, deliberate choice to avoid the cost of comparing addresses
        getPool[token1][token0][fee] = pool;
        emit PoolCreated(token0, token1, fee, tickSpacing, pool);
    }

    /// @inheritdoc IAetherweb3Factory
    function setOwner(address _owner) external override onlyOwner {
        emit OwnerChanged(owner, _owner);
        owner = _owner;
    }

    /// @inheritdoc IAetherweb3Factory
    function enableFeeAmount(uint24 fee, int24 tickSpacing) public override onlyOwner {
        require(fee < 1000000);
        // tick spacing is capped at 16384 to prevent the situation where tickSpacing is so large that
        // TickBitmap#nextInitializedTickWithinOneWord overflows int24 container from a valid tick
        // 16384 ticks represents a >5x price change with ticks of 1 bips
        require(tickSpacing > 0 && tickSpacing < 16384);
        require(feeAmountTickSpacing[fee] == 0);

        feeAmountTickSpacing[fee] = tickSpacing;
        emit FeeAmountEnabled(fee, tickSpacing);
    }
}
