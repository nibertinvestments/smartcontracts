// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import './interfaces/IAetherweb3Router.sol';
import './interfaces/IAetherweb3Factory.sol';
import './interfaces/IAetherweb3Pool.sol';
import './interfaces/IERC20Minimal.sol';
import './libraries/TransferHelper.sol';
import './libraries/SafeCast.sol';

/// @title Aetherweb3 V3 Router
/// @notice Router for swapping and liquidity management in Aetherweb3 pools
contract Aetherweb3Router is IAetherweb3Router {
    using SafeCast for uint256;
    using SafeCast for int256;

    address public immutable factory;
    address public immutable WETH9;

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, 'Transaction too old');
        _;
    }

    constructor(address _factory, address _WETH9) {
        factory = _factory;
        WETH9 = _WETH9;
    }

    receive() external payable {
        require(msg.sender == WETH9, 'Not WETH9');
    }

    /// @inheritdoc IAetherweb3Router
    function exactInputSingle(ExactInputSingleParams calldata params)
        external
        payable
        override
        ensure(params.deadline)
        returns (uint256 amountOut)
    {
        amountOut = _exactInputSingle(params);
    }

    /// @inheritdoc IAetherweb3Router
    function exactInput(ExactInputParams memory params)
        external
        payable
        override
        ensure(params.deadline)
        returns (uint256 amountOut)
    {
        // For simplicity, implement single-hop exact input
        // Multi-hop exact input would require more complex path handling
        require(params.path.length == 43, "Multi-hop exact input not supported");

        (address tokenIn, address tokenOut, uint24 fee) = _decodeFirstPool(params.path);

        ExactInputSingleParams memory singleParams = ExactInputSingleParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            fee: fee,
            recipient: params.recipient,
            deadline: params.deadline,
            amountIn: params.amountIn,
            amountOutMinimum: params.amountOutMinimum,
            sqrtPriceLimitX96: 0
        });

        amountOut = _exactInputSingle(singleParams);
    }

    /// @inheritdoc IAetherweb3Router
    function exactOutputSingle(ExactOutputSingleParams calldata params)
        external
        payable
        override
        ensure(params.deadline)
        returns (uint256 amountIn)
    {
        amountIn = _exactOutputSingle(params);
    }

    /// @inheritdoc IAetherweb3Router
    function exactOutput(ExactOutputParams memory params)
        external
        payable
        override
        ensure(params.deadline)
        returns (uint256 amountIn)
    {
        // For simplicity, implement single-hop exact output
        // Multi-hop exact output would require more complex path handling
        require(params.path.length == 43, "Multi-hop exact output not supported");

        (address tokenIn, address tokenOut, uint24 fee) = _decodeFirstPool(params.path);

        ExactOutputSingleParams memory singleParams = ExactOutputSingleParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            fee: fee,
            recipient: params.recipient,
            deadline: params.deadline,
            amountOut: params.amountOut,
            amountInMaximum: params.amountInMaximum,
            sqrtPriceLimitX96: 0
        });

        amountIn = _exactOutputSingle(singleParams);
    }

    function _exactInputSingle(ExactInputSingleParams memory params) private returns (uint256 amountOut) {
        address pool = IAetherweb3Factory(factory).getPool(params.tokenIn, params.tokenOut, params.fee);
        require(pool != address(0), 'Pool does not exist');

        // Transfer tokens to pool
        TransferHelper.safeTransferFrom(params.tokenIn, msg.sender, pool, params.amountIn);

        // Perform swap
        (int256 amount0, int256 amount1) = IAetherweb3Pool(pool).swap(
            params.recipient,
            params.tokenIn < params.tokenOut, // zeroForOne
            params.amountIn.toInt256(),
            params.sqrtPriceLimitX96,
            abi.encode(msg.sender)
        );

        amountOut = params.tokenIn < params.tokenOut ? uint256(-amount1) : uint256(-amount0);
        require(amountOut >= params.amountOutMinimum, 'Too little received');
    }

    function _exactOutputSingle(ExactOutputSingleParams memory params) private returns (uint256 amountIn) {
        address pool = IAetherweb3Factory(factory).getPool(params.tokenIn, params.tokenOut, params.fee);
        require(pool != address(0), 'Pool does not exist');

        // For exact output, we need to calculate the required input amount
        // This is a simplified implementation - in practice, you'd need more complex logic
        uint256 estimatedAmountIn = params.amountOut * 2; // Rough estimate

        // Transfer estimated tokens to pool
        TransferHelper.safeTransferFrom(params.tokenIn, msg.sender, pool, estimatedAmountIn);

        // Perform swap
        (int256 amount0, int256 amount1) = IAetherweb3Pool(pool).swap(
            params.recipient,
            params.tokenIn < params.tokenOut, // zeroForOne
            -params.amountOut.toInt256(), // negative for exact output
            params.sqrtPriceLimitX96,
            abi.encode(msg.sender)
        );

        amountIn = params.tokenIn < params.tokenOut ? uint256(-amount0) : uint256(-amount1);
        require(amountIn <= params.amountInMaximum, 'Too much requested');

        // Refund excess tokens
        if (estimatedAmountIn > amountIn) {
            TransferHelper.safeTransfer(params.tokenIn, msg.sender, estimatedAmountIn - amountIn);
        }
    }

    function _decodeFirstPool(bytes memory path) private pure returns (address tokenIn, address tokenOut, uint24 fee) {
        require(path.length >= 43, "Invalid path");

        assembly {
            tokenIn := mload(add(add(path, 32), 20))
            tokenOut := mload(add(add(path, 32), 41))
            fee := mload(add(add(path, 32), 62))
        }
    }

    function _decodePathElement(bytes memory path, uint256 index) private pure returns (address tokenOut, uint24 fee) {
        // Simplified path decoding - in practice, this would handle the full path encoding
        require(path.length >= 43, "Invalid path");

        uint256 offset = index * 43;
        assembly {
            tokenOut := mload(add(add(path, 32), add(offset, 20)))
            fee := mload(add(add(path, 32), add(offset, 41)))
        }
    }

    /// @inheritdoc IAetherweb3Router
    function multicall(bytes[] calldata data) external payable override returns (bytes[] memory results) {
        results = new bytes[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            (bool success, bytes memory result) = address(this).delegatecall(data[i]);
            require(success, "Multicall failed");
            results[i] = result;
        }
    }

    /// @inheritdoc IAetherweb3Router
    function unwrapWETH9(uint256 amountMinimum, address recipient) external payable override {
        uint256 balanceWETH9 = IWETH9(WETH9).balanceOf(address(this));
        require(balanceWETH9 >= amountMinimum, 'Insufficient WETH9');

        if (balanceWETH9 > 0) {
            IWETH9(WETH9).withdraw(balanceWETH9);
            TransferHelper.safeTransferETH(recipient, balanceWETH9);
        }
    }

    /// @inheritdoc IAetherweb3Router
    function refundETH() external payable override {
        if (address(this).balance > 0) {
            TransferHelper.safeTransferETH(msg.sender, address(this).balance);
        }
    }

    /// @inheritdoc IAetherweb3Router
    function sweepToken(
        address token,
        uint256 amountMinimum,
        address recipient
    ) external payable override {
        uint256 balanceToken = IERC20Minimal(token).balanceOf(address(this));
        require(balanceToken >= amountMinimum, 'Insufficient token');

        if (balanceToken > 0) {
            TransferHelper.safeTransfer(token, recipient, balanceToken);
        }
    }
}

/// @title Interface for WETH9
interface IWETH9 is IERC20Minimal {
    function deposit() external payable;
    function withdraw(uint256) external;
}
