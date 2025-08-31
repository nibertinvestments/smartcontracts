// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IModularContract.sol";
import "../interfaces/IModularTuple.sol";

interface IUniswapV2Router {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}

interface IUniswapV3Router {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
}

contract SwapLogicModular is IModularContract, Ownable, ReentrancyGuard {
    address public leaderContract;
    bool public paused;

    struct SwapConfig {
        address uniswapV2Router;
        address uniswapV3Router;
        uint256 maxSlippage;      // Maximum slippage in basis points
        uint256 deadlineBuffer;   // Deadline buffer in seconds
        bool preferV3;           // Prefer Uniswap V3 over V2
        bool enableMultiHop;    // Enable multi-hop swaps
        bool enableSplitSwap;    // Enable split swaps across DEXes
    }

    struct SwapRoute {
        address[] path;
        uint256[] fees;          // For V3 pools
        address router;
        uint256 expectedOut;
        uint256 minOut;
    }

    SwapConfig public swapConfig;
    mapping(address => mapping(address => SwapRoute)) public optimalRoutes;
    mapping(address => bool) public supportedTokens;

    event SwapExecuted(
        address indexed user,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        address router
    );
    event RouteOptimized(address indexed tokenIn, address indexed tokenOut, uint256 expectedOut);
    event SwapConfigUpdated(uint256 maxSlippage, bool preferV3);

    modifier onlyLeader() {
        require(msg.sender == leaderContract, "Only leader can call");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    constructor() {
        swapConfig = SwapConfig({
            uniswapV2Router: 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D, // Mainnet
            uniswapV3Router: 0xE592427A0AEce92De3Edee1F18E0157C05861564, // Mainnet
            maxSlippage: 200,     // 2% max slippage
            deadlineBuffer: 300,  // 5 minutes
            preferV3: true,
            enableMultiHop: true,
            enableSplitSwap: false
        });

        // Add common token support
        supportedTokens[0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2] = true; // WETH
        supportedTokens[0xA0b86a33E6441e88C5F2712C3E9b74F5b8F1e6E7] = true; // USDC
        supportedTokens[0x6B175474E89094C44Da98b954EedeAC495271d0F] = true; // DAI
    }

    function setLeader(address _leader) external onlyOwner {
        leaderContract = _leader;
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
    }

    function updateSwapConfig(
        address _v2Router,
        address _v3Router,
        uint256 _maxSlippage,
        uint256 _deadlineBuffer,
        bool _preferV3,
        bool _enableMultiHop,
        bool _enableSplitSwap
    ) external onlyOwner {
        swapConfig = SwapConfig({
            uniswapV2Router: _v2Router,
            uniswapV3Router: _v3Router,
            maxSlippage: _maxSlippage,
            deadlineBuffer: _deadlineBuffer,
            preferV3: _preferV3,
            enableMultiHop: _enableMultiHop,
            enableSplitSwap: _enableSplitSwap
        });
        emit SwapConfigUpdated(_maxSlippage, _preferV3);
    }

    function addSupportedToken(address token) external onlyOwner {
        supportedTokens[token] = true;
    }

    function removeSupportedToken(address token) external onlyOwner {
        supportedTokens[token] = false;
    }

    function executeTuple(
        IModularTuple.TupleType tupleType,
        address caller,
        bytes calldata data
    ) external onlyLeader whenNotPaused nonReentrant returns (bytes memory) {

        if (tupleType == IModularTuple.TupleType.BeforeSwap) {
            (address user, uint256 amountIn, uint256 amountOutMin) = abi.decode(data, (address, uint256, uint256));
            // This would be called before the actual swap
            return abi.encode(validateSwap(user, amountIn, amountOutMin));
        }

        if (tupleType == IModularTuple.TupleType.AfterSwap) {
            (address user, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut) = abi.decode(data, (address, address, address, uint256, uint256, uint256));
            // This would be called after the swap to record metrics
            emit SwapExecuted(user, tokenIn, tokenOut, amountIn, amountOut, address(0));
            return abi.encode(true);
        }

        return abi.encode(true);
    }

    function executeSwap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        address recipient
    ) external onlyLeader whenNotPaused nonReentrant returns (uint256) {
        require(supportedTokens[tokenIn] && supportedTokens[tokenOut], "Tokens not supported");

        // Get optimal route
        SwapRoute memory route = getOptimalRoute(tokenIn, tokenOut, amountIn);

        // Execute swap based on router type
        uint256 amountOut;

        if (route.router == swapConfig.uniswapV3Router && swapConfig.preferV3) {
            amountOut = executeV3Swap(route, amountIn, minAmountOut, recipient);
        } else {
            amountOut = executeV2Swap(route, amountIn, minAmountOut, recipient);
        }

        emit SwapExecuted(recipient, tokenIn, tokenOut, amountIn, amountOut, route.router);
        return amountOut;
    }

    function executeV3Swap(
        SwapRoute memory route,
        uint256 amountIn,
        uint256 minAmountOut,
        address recipient
    ) internal returns (uint256) {
        require(route.path.length >= 2, "Invalid V3 path");

        IUniswapV3Router.ExactInputSingleParams memory params = IUniswapV3Router.ExactInputSingleParams({
            tokenIn: route.path[0],
            tokenOut: route.path[1],
            fee: uint24(route.fees.length > 0 ? route.fees[0] : 3000), // Default 0.3%
            recipient: recipient,
            deadline: block.timestamp + swapConfig.deadlineBuffer,
            amountIn: amountIn,
            amountOutMinimum: minAmountOut,
            sqrtPriceLimitX96: 0
        });

        // Approve token for router
        IERC20(route.path[0]).approve(swapConfig.uniswapV3Router, amountIn);

        return IUniswapV3Router(swapConfig.uniswapV3Router).exactInputSingle(params);
    }

    function executeV2Swap(
        SwapRoute memory route,
        uint256 amountIn,
        uint256 minAmountOut,
        address recipient
    ) internal returns (uint256) {
        require(route.path.length >= 2, "Invalid V2 path");

        // Approve token for router
        IERC20(route.path[0]).approve(swapConfig.uniswapV2Router, amountIn);

        uint[] memory amounts = IUniswapV2Router(swapConfig.uniswapV2Router).swapExactTokensForTokens(
            amountIn,
            minAmountOut,
            route.path,
            recipient,
            block.timestamp + swapConfig.deadlineBuffer
        );

        return amounts[amounts.length - 1];
    }

    function getOptimalRoute(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) public view returns (SwapRoute memory) {
        // Check if we have a cached route
        SwapRoute memory cached = optimalRoutes[tokenIn][tokenOut];
        if (cached.expectedOut > 0) {
            return cached;
        }

        // Calculate optimal route
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;

        uint256[] memory amounts;
        address router;

        if (swapConfig.preferV3 && swapConfig.uniswapV3Router != address(0)) {
            // Try V3 first
            router = swapConfig.uniswapV3Router;
            // For V3, we'd need to query the quoter contract
            amounts = new uint256[](2);
            amounts[0] = amountIn;
            amounts[1] = amountIn * 99 / 100; // Simplified estimation
        } else {
            // Fall back to V2
            router = swapConfig.uniswapV2Router;
            amounts = IUniswapV2Router(router).getAmountsOut(amountIn, path);
        }

        uint256 expectedOut = amounts[amounts.length - 1];
        uint256 minOut = expectedOut * (10000 - swapConfig.maxSlippage) / 10000;

        uint256[] memory fees = new uint256[](0); // Empty for V2

        return SwapRoute({
            path: path,
            fees: fees,
            router: router,
            expectedOut: expectedOut,
            minOut: minOut
        });
    }

    function validateSwap(
        address user,
        uint256 amountIn,
        uint256 amountOutMin
    ) public view returns (bool) {
        // Basic validation
        if (amountIn == 0 || amountOutMin == 0) return false;
        if (user == address(0)) return false;

        // Check reasonable bounds
        if (amountIn > 1000000 ether || amountOutMin > 1000000 ether) return false;

        return true;
    }

    function estimateSwapOutput(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (uint256 expectedOut, uint256 minOut) {
        SwapRoute memory route = getOptimalRoute(tokenIn, tokenOut, amountIn);
        return (route.expectedOut, route.minOut);
    }

    function getContractName() external pure returns (string memory) {
        return "SwapLogicModular";
    }

    function getContractVersion() external pure returns (string memory) {
        return "1.0.0";
    }

    function getContractType() external pure returns (bytes32) {
        return keccak256("SWAP_LOGIC");
    }

    function validate(bytes calldata data) external view returns (bool) {
        if (data.length < 96) return false; // Need at least 3 parameters
        (address tokenIn, address tokenOut, uint256 amountIn) = abi.decode(data, (address, address, uint256));
        return tokenIn != address(0) && tokenOut != address(0) && amountIn > 0;
    }

    function estimateGas(bytes calldata data) external view returns (uint256) {
        // Estimate gas for swap execution
        return 150000; // Conservative estimate for DEX swap
    }

    function isActive() external view returns (bool) {
        return !paused && leaderContract != address(0);
    }

    function getMetadata() external view returns (
        string memory name,
        string memory version,
        bytes32 contractType,
        bool active,
        address leader
    ) {
        return (
            this.getContractName(),
            this.getContractVersion(),
            this.getContractType(),
            this.isActive(),
            leaderContract
        );
    }
}
