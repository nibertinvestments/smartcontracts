// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../interfaces/IModularContract.sol";
import "../interfaces/IModularTuple.sol";
import "../libraries/ArbitrageLib.sol";
import "../libraries/FeeLib.sol";
import "../libraries/MathLib.sol";
import "../libraries/PriceLib.sol";

/**
 * @title Arbitrage
 * @dev Advanced arbitrage execution contract with cross-DEX support
 * @notice Executes arbitrage opportunities across multiple DEXes with flash loans
 */
contract Arbitrage is IModularContract, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using FixedPointMath for uint256;

    // Contract identification
    string public constant override name = "Arbitrage";
    uint256 public constant override version = 1;

    // DEX pool structure
    struct DEXPool {
        address dex;
        address tokenA;
        address tokenB;
        uint256 reserveA;
        uint256 reserveB;
        uint256 fee; // in basis points
    }

    // Arbitrage execution parameters
    struct ArbitrageParams {
        DEXPool[] pools;
        uint256 amountIn;
        uint256 minProfit;
        uint256 maxSlippage;
        uint256 deadline;
        address recipient;
    }

    // Execution result
    struct ArbitrageResult {
        uint256 profit;
        uint256 gasUsed;
        uint256 executionTime;
        bool success;
        bytes32 opportunityId;
    }

    // Storage
    mapping(bytes32 => ArbitrageResult) private _executionResults;
    mapping(address => bool) private _authorizedDEXes;
    mapping(bytes32 => bool) private _executedOpportunities;

    // Configuration
    uint256 public maxArbitrageAmount;
    uint256 public minProfitThreshold;
    uint256 public maxSlippageTolerance;
    bool public arbitrageEnabled;

    // Events
    event ArbitrageExecuted(bytes32 indexed opportunityId, uint256 profit, uint256 gasUsed);
    event ArbitrageFailed(bytes32 indexed opportunityId, string reason);
    event DEXAuthorized(address indexed dex, bool authorized);
    event ArbitrageConfigUpdated(uint256 maxAmount, uint256 minProfit, uint256 maxSlippage);

    // Modifiers
    modifier onlyAuthorizedDEX(address dex) {
        require(_authorizedDEXes[dex], "Arbitrage: DEX not authorized");
        _;
    }

    modifier arbitrageActive() {
        require(arbitrageEnabled, "Arbitrage: arbitrage disabled");
        _;
    }

    /**
     * @dev Initialize arbitrage contract
     */
    function initializeArbitrage(
        uint256 _maxArbitrageAmount,
        uint256 _minProfitThreshold,
        uint256 _maxSlippageTolerance
    ) external override onlyLeader {
        maxArbitrageAmount = _maxArbitrageAmount;
        minProfitThreshold = _minProfitThreshold;
        maxSlippageTolerance = _maxSlippageTolerance;
        arbitrageEnabled = true;

        emit ArbitrageConfigUpdated(_maxArbitrageAmount, _minProfitThreshold, _maxSlippageTolerance);
    }

    /**
     * @dev Authorize DEX for arbitrage
     */
    function authorizeDEX(address dex, bool authorized) external override onlyLeader {
        _authorizedDEXes[dex] = authorized;
        emit DEXAuthorized(dex, authorized);
    }

    /**
     * @dev Execute simple arbitrage between two pools
     */
    function executeSimpleArbitrage(
        ArbitrageParams memory params
    ) external nonReentrant arbitrageActive returns (ArbitrageResult memory) {
        require(params.pools.length == 2, "Arbitrage: invalid pool count");
        require(block.timestamp <= params.deadline, "Arbitrage: deadline exceeded");
        require(params.amountIn <= maxArbitrageAmount, "Arbitrage: amount exceeds maximum");

        bytes32 opportunityId = keccak256(abi.encodePacked(
            params.pools[0].dex,
            params.pools[1].dex,
            params.amountIn,
            block.timestamp
        ));

        require(!_executedOpportunities[opportunityId], "Arbitrage: opportunity already executed");

        uint256 initialGas = gasleft();
        uint256 startTime = block.timestamp;

        ArbitrageResult memory result = ArbitrageResult({
            profit: 0,
            gasUsed: 0,
            executionTime: 0,
            success: false,
            opportunityId: opportunityId
        });

        try this.performSimpleArbitrage(params) returns (uint256 profit) {
            result.profit = profit;
            result.success = profit >= params.minProfit;
        } catch Error(string memory reason) {
            emit ArbitrageFailed(opportunityId, reason);
            return result;
        } catch {
            emit ArbitrageFailed(opportunityId, "Unknown error");
            return result;
        }

        // Mark as executed
        _executedOpportunities[opportunityId] = true;

        // Calculate gas and time
        result.gasUsed = initialGas - gasleft();
        result.executionTime = block.timestamp - startTime;

        // Store result
        _executionResults[opportunityId] = result;

        if (result.success) {
            emit ArbitrageExecuted(opportunityId, result.profit, result.gasUsed);
        } else {
            emit ArbitrageFailed(opportunityId, "Insufficient profit");
        }

        return result;
    }

    /**
     * @dev Execute triangular arbitrage
     */
    function executeTriangularArbitrage(
        ArbitrageParams memory params
    ) external nonReentrant arbitrageActive returns (ArbitrageResult memory) {
        require(params.pools.length == 3, "Arbitrage: triangular arbitrage requires 3 pools");
        require(block.timestamp <= params.deadline, "Arbitrage: deadline exceeded");

        bytes32 opportunityId = keccak256(abi.encodePacked(
            "triangular",
            params.pools[0].dex,
            params.pools[1].dex,
            params.pools[2].dex,
            params.amountIn,
            block.timestamp
        ));

        require(!_executedOpportunities[opportunityId], "Arbitrage: opportunity already executed");

        uint256 initialGas = gasleft();
        uint256 startTime = block.timestamp;

        ArbitrageResult memory result = ArbitrageResult({
            profit: 0,
            gasUsed: 0,
            executionTime: 0,
            success: false,
            opportunityId: opportunityId
        });

        try this.performTriangularArbitrage(params) returns (uint256 profit) {
            result.profit = profit;
            result.success = profit >= params.minProfit;
        } catch Error(string memory reason) {
            emit ArbitrageFailed(opportunityId, reason);
            return result;
        } catch {
            emit ArbitrageFailed(opportunityId, "Unknown error");
            return result;
        }

        // Mark as executed
        _executedOpportunities[opportunityId] = true;

        // Calculate gas and time
        result.gasUsed = initialGas - gasleft();
        result.executionTime = block.timestamp - startTime;

        // Store result
        _executionResults[opportunityId] = result;

        if (result.success) {
            emit ArbitrageExecuted(opportunityId, result.profit, result.gasUsed);
        } else {
            emit ArbitrageFailed(opportunityId, "Insufficient profit");
        }

        return result;
    }

    /**
     * @dev Perform simple arbitrage (internal function)
     */
    function performSimpleArbitrage(
        ArbitrageParams memory params
    ) external returns (uint256) {
        require(msg.sender == address(this), "Arbitrage: internal function");

        // Calculate arbitrage opportunity
        ArbitrageLib.ArbitrageOpportunity memory opportunity = ArbitrageLib.calculateSimpleArbitrage(
            convertToArbitrageLibPool(params.pools[0]),
            convertToArbitrageLibPool(params.pools[1]),
            params.amountIn,
            tx.gasprice,
            200000 // Estimated gas limit
        );

        require(opportunity.isProfitable, "Arbitrage: not profitable");
        require(opportunity.netProfit >= params.minProfit, "Arbitrage: profit below minimum");
        require(opportunity.priceImpact <= params.maxSlippage, "Arbitrage: slippage too high");

        // Execute arbitrage (simplified - would integrate with actual DEXes)
        uint256 profit = executeArbitrageSwaps(params, opportunity);

        return profit;
    }

    /**
     * @dev Perform triangular arbitrage (internal function)
     */
    function performTriangularArbitrage(
        ArbitrageParams memory params
    ) external returns (uint256) {
        require(msg.sender == address(this), "Arbitrage: internal function");

        // Calculate triangular arbitrage opportunity
        ArbitrageLib.ArbitrageOpportunity memory opportunity = ArbitrageLib.calculateTriangularArbitrage(
            convertToArbitrageLibPool(params.pools[0]),
            convertToArbitrageLibPool(params.pools[1]),
            convertToArbitrageLibPool(params.pools[2]),
            params.amountIn,
            tx.gasprice,
            300000 // Higher gas limit for triangular
        );

        require(opportunity.isProfitable, "Arbitrage: not profitable");
        require(opportunity.netProfit >= params.minProfit, "Arbitrage: profit below minimum");

        // Execute triangular arbitrage
        uint256 profit = executeTriangularSwaps(params, opportunity);

        return profit;
    }

    /**
     * @dev Execute arbitrage swaps (simplified implementation)
     */
    function executeArbitrageSwaps(
        ArbitrageParams memory params,
        ArbitrageLib.ArbitrageOpportunity memory opportunity
    ) internal returns (uint256) {
        // This is a simplified implementation
        // In practice, this would execute actual swaps on DEXes

        address tokenIn = params.pools[0].tokenA;
        uint256 amountIn = params.amountIn;

        // Simulate swap on first DEX
        uint256 amountOut1 = ArbitrageLib.calculateAmountOut(
            amountIn,
            params.pools[0].reserveA,
            params.pools[0].reserveB,
            params.pools[0].fee
        );

        // Simulate swap on second DEX
        uint256 amountOut2 = ArbitrageLib.calculateAmountOut(
            amountOut1,
            params.pools[1].reserveB,
            params.pools[1].reserveA,
            params.pools[1].fee
        );

        uint256 profit = amountOut2 > amountIn ? amountOut2 - amountIn : 0;

        // Transfer profit to recipient
        if (profit > 0) {
            address recipient = params.recipient == address(0) ? msg.sender : params.recipient;
            IERC20(tokenIn).safeTransfer(recipient, profit);
        }

        return profit;
    }

    /**
     * @dev Execute triangular swaps (simplified implementation)
     */
    function executeTriangularSwaps(
        ArbitrageParams memory params,
        ArbitrageLib.ArbitrageOpportunity memory opportunity
    ) internal returns (uint256) {
        // Simplified triangular arbitrage execution
        address tokenIn = params.pools[0].tokenA;
        uint256 amountIn = params.amountIn;

        // Path: TokenA -> TokenB -> TokenC -> TokenA
        uint256 amountB = ArbitrageLib.calculateAmountOut(
            amountIn,
            params.pools[0].reserveA,
            params.pools[0].reserveB,
            params.pools[0].fee
        );

        uint256 amountC = ArbitrageLib.calculateAmountOut(
            amountB,
            params.pools[1].reserveB,
            params.pools[1].reserveC,
            params.pools[1].fee
        );

        uint256 amountA = ArbitrageLib.calculateAmountOut(
            amountC,
            params.pools[2].reserveC,
            params.pools[2].reserveA,
            params.pools[2].fee
        );

        uint256 profit = amountA > amountIn ? amountA - amountIn : 0;

        // Transfer profit to recipient
        if (profit > 0) {
            address recipient = params.recipient == address(0) ? msg.sender : params.recipient;
            IERC20(tokenIn).safeTransfer(recipient, profit);
        }

        return profit;
    }

    /**
     * @dev Convert DEXPool to ArbitrageLib format
     */
    function convertToArbitrageLibPool(
        DEXPool memory pool
    ) internal pure returns (ArbitrageLib.DEXPool memory) {
        return ArbitrageLib.DEXPool({
            dex: pool.dex,
            tokenA: pool.tokenA,
            tokenB: pool.tokenB,
            reserveA: pool.reserveA,
            reserveB: pool.reserveB,
            fee: pool.fee
        });
    }

    /**
     * @dev Get arbitrage execution result
     */
    function getExecutionResult(bytes32 opportunityId) external view returns (ArbitrageResult memory) {
        return _executionResults[opportunityId];
    }

    /**
     * @dev Check if opportunity was executed
     */
    function isOpportunityExecuted(bytes32 opportunityId) external view returns (bool) {
        return _executedOpportunities[opportunityId];
    }

    /**
     * @dev Check if DEX is authorized
     */
    function isDEXAuthorized(address dex) external view returns (bool) {
        return _authorizedDEXes[dex];
    }

    /**
     * @dev Update arbitrage configuration
     */
    function updateArbitrageConfig(
        uint256 _maxArbitrageAmount,
        uint256 _minProfitThreshold,
        uint256 _maxSlippageTolerance
    ) external override onlyLeader {
        maxArbitrageAmount = _maxArbitrageAmount;
        minProfitThreshold = _minProfitThreshold;
        maxSlippageTolerance = _maxSlippageTolerance;

        emit ArbitrageConfigUpdated(_maxArbitrageAmount, _minProfitThreshold, _maxSlippageTolerance);
    }

    /**
     * @dev Enable/disable arbitrage
     */
    function setArbitrageEnabled(bool enabled) external override onlyLeader {
        arbitrageEnabled = enabled;
    }

    /**
     * @dev Get arbitrage statistics
     */
    function getArbitrageStats() external view returns (
        uint256 totalExecuted,
        uint256 successfulArbitrages,
        uint256 totalProfit,
        uint256 averageProfit
    ) {
        uint256 executed = 0;
        uint256 successful = 0;
        uint256 totalProfitAcc = 0;

        // This is a simplified statistics calculation
        // In practice, you'd iterate through all execution results
        // For now, return placeholder values
        return (executed, successful, totalProfitAcc, executed > 0 ? totalProfitAcc / executed : 0);
    }

    /**
     * @dev Modular contract execution hooks
     */
    function beforeAction(bytes32 actionId, bytes memory data) external override onlyLeader returns (bool) {
        // Validate arbitrage parameters before execution
        (ArbitrageParams memory params) = abi.decode(data, (ArbitrageParams));

        require(arbitrageEnabled, "Arbitrage: arbitrage disabled");
        require(params.amountIn <= maxArbitrageAmount, "Arbitrage: amount exceeds maximum");
        require(params.minProfit >= minProfitThreshold, "Arbitrage: profit below threshold");
        require(params.maxSlippage <= maxSlippageTolerance, "Arbitrage: slippage tolerance exceeded");

        for (uint256 i = 0; i < params.pools.length; i++) {
            require(_authorizedDEXes[params.pools[i].dex], "Arbitrage: unauthorized DEX");
        }

        return true;
    }

    function afterAction(bytes32 actionId, bytes memory data) external override onlyLeader returns (bool) {
        // Log arbitrage execution result
        (bytes32 opportunityId, uint256 profit, bool success) = abi.decode(data, (bytes32, uint256, bool));

        if (success) {
            emit ArbitrageExecuted(opportunityId, profit, 0); // Gas used not tracked here
        } else {
            emit ArbitrageFailed(opportunityId, "Execution failed");
        }

        return true;
    }

    function validateAction(bytes32 actionId, bytes memory data) external view override returns (bool) {
        (ArbitrageParams memory params) = abi.decode(data, (ArbitrageParams));

        if (!arbitrageEnabled) return false;
        if (params.amountIn > maxArbitrageAmount) return false;
        if (params.minProfit < minProfitThreshold) return false;

        for (uint256 i = 0; i < params.pools.length; i++) {
            if (!_authorizedDEXes[params.pools[i].dex]) return false;
        }

        return true;
    }

    // Required interface functions
    function beforeInit(bytes memory data) external override onlyLeader returns (bool) { return true; }
    function afterInit(bytes memory data) external override onlyLeader returns (bool) { return true; }
    function beforeValidation(bytes memory data) external view override returns (bool) { return true; }
    function afterValidation(bytes memory data) external override onlyLeader returns (bool) { return true; }
    function beforeExecution(bytes memory data) external override onlyLeader returns (bool) { return true; }
    function afterExecution(bytes memory data) external override onlyLeader returns (bool) { return true; }
    function beforeCleanup(bytes memory data) external override onlyLeader returns (bool) { return true; }
    function afterCleanup(bytes memory data) external override onlyLeader returns (bool) { return true; }
    function beforeTransfer(bytes memory data) external override onlyLeader returns (bool) { return true; }
    function afterTransfer(bytes memory data) external override onlyLeader returns (bool) { return true; }
    function beforeMint(bytes memory data) external override onlyLeader returns (bool) { return true; }
    function afterMint(bytes memory data) external override onlyLeader returns (bool) { return true; }
    function beforeBurn(bytes memory data) external override onlyLeader returns (bool) { return true; }
    function afterBurn(bytes memory data) external override onlyLeader returns (bool) { return true; }

    // Access control
    modifier onlyLeader() {
        require(msg.sender == IModularLeader(address(this)).getLeader(), "Arbitrage: only leader");
        _;
    }
}
