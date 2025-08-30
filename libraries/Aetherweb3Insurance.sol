// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Aetherweb3Math.sol";
import "./Aetherweb3Safety.sol";

/**
 * @title Aetherweb3Insurance
 * @dev Insurance and risk management utility library
 * @notice Provides insurance calculations, risk assessments, and coverage utilities
 */
library Aetherweb3Insurance {
    using Aetherweb3Math for uint256;

    // Insurance policy information
    struct InsurancePolicy {
        uint256 policyId;         // Unique policy ID
        address policyHolder;     // Policy holder address
        address insurer;          // Insurance provider
        uint256 coverageAmount;   // Maximum coverage amount
        uint256 premiumAmount;    // Premium paid
        uint256 deductible;       // Deductible amount
        uint256 coveragePeriod;   // Coverage period in seconds
        uint256 startTime;        // Policy start time
        uint256 endTime;          // Policy end time
        PolicyStatus status;      // Policy status
        RiskLevel riskLevel;      // Risk assessment level
        CoverageType coverageType; // Type of coverage
    }

    // Policy status enumeration
    enum PolicyStatus {
        ACTIVE,
        EXPIRED,
        CLAIMED,
        CANCELLED,
        UNDER_REVIEW
    }

    // Risk level enumeration
    enum RiskLevel {
        LOW,
        MEDIUM,
        HIGH,
        CRITICAL
    }

    // Coverage type enumeration
    enum CoverageType {
        LIQUIDITY_MINING,
        IMPERMANENT_LOSS,
        SMART_CONTRACT_BUG,
        HACK_EXPLOIT,
        MARKET_VOLATILITY,
        COUNTERPARTY_DEFAULT
    }

    // Insurance claim information
    struct InsuranceClaim {
        uint256 claimId;          // Unique claim ID
        uint256 policyId;         // Associated policy ID
        address claimant;         // Claim submitter
        uint256 claimAmount;      // Claimed amount
        uint256 approvedAmount;   // Approved payout amount
        uint256 incidentTime;     // Incident timestamp
        string incidentDetails;   // Incident description
        ClaimStatus status;       // Claim status
        uint256 processingTime;   // Claim processing timestamp
        bytes32 evidenceHash;     // Evidence hash
    }

    // Claim status enumeration
    enum ClaimStatus {
        SUBMITTED,
        UNDER_REVIEW,
        APPROVED,
        REJECTED,
        PAID_OUT
    }

    // Risk assessment parameters
    struct RiskAssessment {
        uint256 protocolRisk;     // Protocol risk score
        uint256 marketRisk;       // Market risk score
        uint256 liquidityRisk;    // Liquidity risk score
        uint256 smartContractRisk; // Smart contract risk score
        uint256 overallRisk;      // Overall risk score
        uint256 recommendedPremium; // Recommended premium
        RiskLevel assessedLevel;  // Assessed risk level
    }

    // Insurance pool information
    struct InsurancePool {
        address poolToken;        // Pool token address
        uint256 totalPremiums;    // Total premiums collected
        uint256 totalCoverage;    // Total coverage provided
        uint256 poolReserves;     // Pool reserves
        uint256 utilizationRate;  // Pool utilization rate
        uint256 minReservesRatio; // Minimum reserves ratio
        bool isActive;           // Pool active status
    }

    /**
     * @dev Calculates insurance premium based on risk factors
     * @param coverageAmount Coverage amount requested
     * @param coveragePeriod Coverage period in seconds
     * @param riskLevel Risk level assessment
     * @param basePremiumRate Base premium rate
     * @param riskMultiplier Risk multiplier
     * @return premium Calculated premium amount
     */
    function calculateInsurancePremium(
        uint256 coverageAmount,
        uint256 coveragePeriod,
        RiskLevel riskLevel,
        uint256 basePremiumRate,
        uint256 riskMultiplier
    ) internal pure returns (uint256 premium) {
        uint256 riskFactor = getRiskMultiplier(riskLevel);
        uint256 timeFactor = coveragePeriod / (365 days); // Annualize

        uint256 basePremium = coverageAmount.wmul(basePremiumRate);
        uint256 riskAdjustedPremium = basePremium.wmul(riskFactor);
        premium = riskAdjustedPremium.wmul(timeFactor).wmul(riskMultiplier);
    }

    /**
     * @dev Gets risk multiplier for risk level
     * @param riskLevel Risk level
     * @return multiplier Risk multiplier
     */
    function getRiskMultiplier(RiskLevel riskLevel) internal pure returns (uint256 multiplier) {
        if (riskLevel == RiskLevel.LOW) return Aetherweb3Math.WAD / 4;      // 0.25x
        if (riskLevel == RiskLevel.MEDIUM) return Aetherweb3Math.WAD / 2;   // 0.5x
        if (riskLevel == RiskLevel.HIGH) return Aetherweb3Math.WAD;        // 1x
        if (riskLevel == RiskLevel.CRITICAL) return Aetherweb3Math.WAD * 2; // 2x
        return Aetherweb3Math.WAD; // Default
    }

    /**
     * @dev Calculates claim payout amount
     * @param claim Insurance claim
     * @param policy Insurance policy
     * @param lossAmount Actual loss amount
     * @param deductible Deductible amount
     * @return payoutAmount Calculated payout amount
     */
    function calculateClaimPayout(
        InsuranceClaim memory claim,
        InsurancePolicy memory policy,
        uint256 lossAmount,
        uint256 deductible
    ) internal pure returns (uint256 payoutAmount) {
        if (lossAmount <= deductible) return 0;

        uint256 coveredLoss = lossAmount - deductible;
        uint256 maxPayout = Aetherweb3Math.min(coveredLoss, policy.coverageAmount);

        // Apply any claim limits or conditions
        payoutAmount = maxPayout;
    }

    /**
     * @dev Assesses protocol risk based on various factors
     * @param tvl Total value locked
     * @param volume24h 24h volume
     * @param auditStatus Audit completion status (0-100)
     * @param teamReputation Team reputation score (0-100)
     * @param marketVolatility Market volatility index
     * @return assessment Risk assessment
     */
    function assessProtocolRisk(
        uint256 tvl,
        uint256 volume24h,
        uint256 auditStatus,
        uint256 teamReputation,
        uint256 marketVolatility
    ) internal pure returns (RiskAssessment memory assessment) {
        // Protocol risk factors
        uint256 tvlRisk = calculateTVLRisk(tvl);
        uint256 volumeRisk = calculateVolumeRisk(volume24h, tvl);
        uint256 auditRisk = (100 - auditStatus) * Aetherweb3Math.WAD / 100;
        uint256 reputationRisk = (100 - teamReputation) * Aetherweb3Math.WAD / 100;
        uint256 volatilityRisk = marketVolatility;

        // Weighted average
        assessment.protocolRisk = (
            tvlRisk * 30 +
            volumeRisk * 20 +
            auditRisk * 25 +
            reputationRisk * 15 +
            volatilityRisk * 10
        ) / 100;

        assessment.marketRisk = volatilityRisk;
        assessment.liquidityRisk = (tvlRisk + volumeRisk) / 2;
        assessment.smartContractRisk = auditRisk;

        assessment.overallRisk = (
            assessment.protocolRisk * 40 +
            assessment.marketRisk * 30 +
            assessment.liquidityRisk * 20 +
            assessment.smartContractRisk * 10
        ) / 100;

        assessment.assessedLevel = getRiskLevelFromScore(assessment.overallRisk);
        assessment.recommendedPremium = calculateRecommendedPremium(
            assessment.overallRisk,
            tvl
        );
    }

    /**
     * @dev Calculates TVL-based risk
     * @param tvl Total value locked
     * @return risk TVL risk score
     */
    function calculateTVLRisk(uint256 tvl) internal pure returns (uint256 risk) {
        if (tvl < 100000 * 1e18) return 80 * Aetherweb3Math.WAD / 100; // High risk for low TVL
        if (tvl < 1000000 * 1e18) return 60 * Aetherweb3Math.WAD / 100; // Medium-high risk
        if (tvl < 10000000 * 1e18) return 40 * Aetherweb3Math.WAD / 100; // Medium risk
        if (tvl < 100000000 * 1e18) return 20 * Aetherweb3Math.WAD / 100; // Low-medium risk
        return 10 * Aetherweb3Math.WAD / 100; // Low risk for high TVL
    }

    /**
     * @dev Calculates volume-based risk
     * @param volume24h 24h volume
     * @param tvl Total value locked
     * @return risk Volume risk score
     */
    function calculateVolumeRisk(
        uint256 volume24h,
        uint256 tvl
    ) internal pure returns (uint256 risk) {
        if (tvl == 0) return 50 * Aetherweb3Math.WAD / 100;

        uint256 volumeRatio = volume24h.wdiv(tvl);
        if (volumeRatio < Aetherweb3Math.WAD / 100) return 70 * Aetherweb3Math.WAD / 100; // Low volume = high risk
        if (volumeRatio < Aetherweb3Math.WAD / 10) return 40 * Aetherweb3Math.WAD / 100;  // Medium volume
        return 20 * Aetherweb3Math.WAD / 100; // High volume = low risk
    }

    /**
     * @dev Gets risk level from risk score
     * @param riskScore Risk score
     * @return riskLevel Risk level
     */
    function getRiskLevelFromScore(uint256 riskScore) internal pure returns (RiskLevel riskLevel) {
        if (riskScore < 25 * Aetherweb3Math.WAD / 100) return RiskLevel.LOW;
        if (riskScore < 50 * Aetherweb3Math.WAD / 100) return RiskLevel.MEDIUM;
        if (riskScore < 75 * Aetherweb3Math.WAD / 100) return RiskLevel.HIGH;
        return RiskLevel.CRITICAL;
    }

    /**
     * @dev Calculates recommended premium based on risk
     * @param riskScore Risk score
     * @param coverageAmount Coverage amount
     * @return premium Recommended premium
     */
    function calculateRecommendedPremium(
        uint256 riskScore,
        uint256 coverageAmount
    ) internal pure returns (uint256 premium) {
        uint256 baseRate = 5 * Aetherweb3Math.WAD / 1000; // 0.5% base rate
        uint256 riskAdjustment = riskScore / 10; // Risk adjustment factor
        uint256 adjustedRate = baseRate + riskAdjustment;

        premium = coverageAmount.wmul(adjustedRate);
    }

    /**
     * @dev Validates insurance policy parameters
     * @param policy Insurance policy
     * @return isValid True if policy is valid
     */
    function validateInsurancePolicy(
        InsurancePolicy memory policy
    ) internal pure returns (bool isValid) {
        if (policy.policyHolder == address(0)) return false;
        if (policy.insurer == address(0)) return false;
        if (policy.coverageAmount == 0) return false;
        if (policy.premiumAmount == 0) return false;
        if (policy.startTime >= policy.endTime) return false;
        if (policy.coveragePeriod == 0) return false;
        return true;
    }

    /**
     * @dev Calculates insurance pool utilization
     * @param pool Insurance pool
     * @return utilization Utilization rate
     */
    function calculatePoolUtilization(
        InsurancePool memory pool
    ) internal pure returns (uint256 utilization) {
        if (pool.poolReserves == 0) return 0;
        utilization = pool.totalCoverage.wdiv(pool.poolReserves);
    }

    /**
     * @dev Checks if insurance pool needs rebalancing
     * @param pool Insurance pool
     * @param targetUtilization Target utilization rate
     * @return needsRebalance True if rebalancing is needed
     */
    function needsPoolRebalancing(
        InsurancePool memory pool,
        uint256 targetUtilization
    ) internal pure returns (bool needsRebalance) {
        uint256 currentUtilization = calculatePoolUtilization(pool);
        uint256 deviation = currentUtilization > targetUtilization ?
            currentUtilization - targetUtilization :
            targetUtilization - currentUtilization;

        return deviation > 10 * Aetherweb3Math.WAD / 100; // 10% deviation threshold
    }

    /**
     * @dev Calculates impermanent loss insurance payout
     * @param initialValue Initial position value
     * @param currentValue Current position value
     * @param coverageRatio Coverage ratio (0-100)
     * @return payout Insurance payout amount
     */
    function calculateImpermanentLossPayout(
        uint256 initialValue,
        uint256 currentValue,
        uint256 coverageRatio
    ) internal pure returns (uint256 payout) {
        if (currentValue >= initialValue) return 0;

        uint256 loss = initialValue - currentValue;
        payout = loss.wmul(coverageRatio);
    }

    /**
     * @dev Calculates smart contract bug coverage
     * @param contractValue Contract TVL
     * @param bugSeverity Bug severity (1-10)
     * @param coverageLimit Maximum coverage limit
     * @return coverage Recommended coverage amount
     */
    function calculateSmartContractCoverage(
        uint256 contractValue,
        uint256 bugSeverity,
        uint256 coverageLimit
    ) internal pure returns (uint256 coverage) {
        uint256 baseCoverage = contractValue.wmul(bugSeverity).wmul(Aetherweb3Math.WAD / 10);
        coverage = Aetherweb3Math.min(baseCoverage, coverageLimit);
    }

    /**
     * @dev Assesses counterparty risk
     * @param transactionVolume Transaction volume
     * @param successRate Success rate (0-100)
     * @param collateralRatio Collateral ratio
     * @return riskScore Counterparty risk score
     */
    function assessCounterpartyRisk(
        uint256 transactionVolume,
        uint256 successRate,
        uint256 collateralRatio
    ) internal pure returns (uint256 riskScore) {
        uint256 volumeRisk = transactionVolume < 100000 * 1e18 ?
            30 * Aetherweb3Math.WAD / 100 : 10 * Aetherweb3Math.WAD / 100;

        uint256 successRisk = (100 - successRate) * Aetherweb3Math.WAD / 100;

        uint256 collateralRisk = collateralRatio < Aetherweb3Math.WAD ?
            (Aetherweb3Math.WAD - collateralRatio) / 2 : 0;

        riskScore = (volumeRisk + successRisk + collateralRisk) / 3;
    }

    /**
     * @dev Calculates insurance claim processing time
     * @param claim Insurance claim
     * @param baseProcessingTime Base processing time
     * @param complexityFactor Complexity factor
     * @return processingTime Estimated processing time
     */
    function calculateClaimProcessingTime(
        InsuranceClaim memory claim,
        uint256 baseProcessingTime,
        uint256 complexityFactor
    ) internal pure returns (uint256 processingTime) {
        processingTime = baseProcessingTime.wmul(complexityFactor);
    }

    /**
     * @dev Validates insurance claim
     * @param claim Insurance claim
     * @param policy Insurance policy
     * @param currentTime Current timestamp
     * @return isValid True if claim is valid
     */
    function validateInsuranceClaim(
        InsuranceClaim memory claim,
        InsurancePolicy memory policy,
        uint256 currentTime
    ) internal pure returns (bool isValid) {
        if (claim.claimant != policy.policyHolder) return false;
        if (claim.claimAmount > policy.coverageAmount) return false;
        if (claim.incidentTime > currentTime) return false;
        if (claim.incidentTime < policy.startTime) return false;
        if (claim.incidentTime > policy.endTime) return false;
        if (bytes(claim.incidentDetails).length == 0) return false;
        return true;
    }

    /**
     * @dev Calculates insurance pool health score
     * @param pool Insurance pool
     * @return healthScore Pool health score (0-100)
     */
    function calculatePoolHealthScore(
        InsurancePool memory pool
    ) internal pure returns (uint256 healthScore) {
        if (!pool.isActive) return 0;

        uint256 reservesRatio = pool.poolReserves.wdiv(pool.totalCoverage);
        uint256 utilizationScore = 100 - pool.utilizationRate / Aetherweb3Math.WAD * 100;

        uint256 reservesScore = reservesRatio >= pool.minReservesRatio ?
            100 : (reservesRatio * 100) / pool.minReservesRatio;

        healthScore = (reservesScore + utilizationScore) / 2;
    }

    /**
     * @dev Calculates optimal insurance coverage
     * @param assetValue Asset value to insure
     * @param riskLevel Risk level
     * @param budget Insurance budget
     * @return optimalCoverage Optimal coverage amount
     */
    function calculateOptimalCoverage(
        uint256 assetValue,
        RiskLevel riskLevel,
        uint256 budget
    ) internal pure returns (uint256 optimalCoverage) {
        uint256 riskFactor = getRiskMultiplier(riskLevel);
        uint256 recommendedCoverage = assetValue.wmul(riskFactor);

        optimalCoverage = Aetherweb3Math.min(recommendedCoverage, budget);
    }
}
