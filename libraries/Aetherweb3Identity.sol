// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Aetherweb3Math.sol";
import "./Aetherweb3Safety.sol";

/**
 * @title Aetherweb3Identity
 * @dev Decentralized identity and reputation utility library
 * @notice Provides identity verification, reputation scoring, and trust calculations
 */
library Aetherweb3Identity {
    using Aetherweb3Math for uint256;

    // Identity information
    struct Identity {
        address owner;            // Identity owner
        bytes32 identityHash;     // Identity hash
        uint256 creationTime;     // Creation timestamp
        uint256 lastUpdate;       // Last update timestamp
        uint256 reputationScore;  // Reputation score
        uint256 trustLevel;       // Trust level
        IdentityStatus status;    // Identity status
        VerificationLevel verificationLevel; // Verification level
        mapping(bytes32 => Attribute) attributes; // Identity attributes
    }

    // Identity status enumeration
    enum IdentityStatus {
        PENDING,
        ACTIVE,
        SUSPENDED,
        REVOKED,
        EXPIRED
    }

    // Verification level enumeration
    enum VerificationLevel {
        NONE,
        BASIC,
        INTERMEDIATE,
        ADVANCED,
        MAXIMUM
    }

    // Identity attribute
    struct Attribute {
        bytes32 key;             // Attribute key
        bytes32 value;           // Attribute value
        address issuer;          // Attribute issuer
        uint256 issuanceTime;    // Issuance timestamp
        uint256 expirationTime;  // Expiration timestamp
        bool verified;           // Verification status
        uint256 confidence;      // Confidence score
    }

    // Reputation event
    struct ReputationEvent {
        address subject;         // Subject of reputation change
        address issuer;          // Reputation issuer
        int256 scoreChange;      // Reputation score change
        uint256 timestamp;       // Event timestamp
        bytes32 reason;          // Reason for change
        uint256 weight;          // Event weight
        EventType eventType;     // Event type
    }

    // Event type enumeration
    enum EventType {
        POSITIVE,
        NEGATIVE,
        NEUTRAL,
        VERIFICATION,
        INTERACTION
    }

    // Trust relationship
    struct TrustRelationship {
        address truster;         // Entity granting trust
        address trustee;         // Entity receiving trust
        uint256 trustScore;      // Trust score
        uint256 establishedTime; // Relationship establishment time
        uint256 lastInteraction; // Last interaction timestamp
        bool active;             // Relationship active status
        uint256 interactionCount; // Number of interactions
    }

    // Identity verification request
    struct VerificationRequest {
        address requester;       // Verification requester
        VerificationLevel requestedLevel; // Requested verification level
        uint256 requestTime;     // Request timestamp
        uint256 processingTime;  // Processing timestamp
        VerificationStatus status; // Verification status
        bytes32 evidenceHash;    // Evidence hash
        address verifier;        // Assigned verifier
    }

    // Verification status enumeration
    enum VerificationStatus {
        PENDING,
        UNDER_REVIEW,
        APPROVED,
        REJECTED,
        EXPIRED
    }

    // Reputation statistics
    struct ReputationStats {
        uint256 totalScore;      // Total reputation score
        uint256 positiveEvents;  // Positive reputation events
        uint256 negativeEvents;  // Negative reputation events
        uint256 neutralEvents;   // Neutral reputation events
        uint256 averageScore;    // Average reputation score
        uint256 volatility;      // Reputation volatility
        uint256 consistency;     // Reputation consistency
    }

    /**
     * @dev Calculates identity reputation score
     * @param events Array of reputation events
     * @param decayFactor Reputation decay factor
     * @param currentTime Current timestamp
     * @return reputationScore Calculated reputation score
     */
    function calculateReputationScore(
        ReputationEvent[] memory events,
        uint256 decayFactor,
        uint256 currentTime
    ) internal pure returns (uint256 reputationScore) {
        uint256 totalWeightedScore = 0;
        uint256 totalWeight = 0;

        for (uint256 i = 0; i < events.length; i++) {
            uint256 age = currentTime - events[i].timestamp;
            uint256 timeWeight = Aetherweb3Math.WAD / (Aetherweb3Math.WAD + age * decayFactor / 365 days);

            uint256 eventWeight = events[i].weight * timeWeight / Aetherweb3Math.WAD;
            uint256 score = events[i].scoreChange >= 0 ?
                uint256(events[i].scoreChange) :
                0; // Only count positive for reputation

            totalWeightedScore += score * eventWeight;
            totalWeight += eventWeight;
        }

        if (totalWeight == 0) return 0;
        reputationScore = totalWeightedScore / totalWeight;
    }

    /**
     * @dev Calculates trust score between two entities
     * @param relationship Trust relationship
     * @param interactionHistory Array of interaction scores
     * @param currentTime Current timestamp
     * @return trustScore Calculated trust score
     */
    function calculateTrustScore(
        TrustRelationship memory relationship,
        uint256[] memory interactionHistory,
        uint256 currentTime
    ) internal pure returns (uint256 trustScore) {
        if (!relationship.active) return 0;

        uint256 timeSinceLastInteraction = currentTime - relationship.lastInteraction;
        uint256 recencyFactor = timeSinceLastInteraction < 30 days ?
            Aetherweb3Math.WAD :
            Aetherweb3Math.WAD / (1 + timeSinceLastInteraction / 30 days);

        uint256 interactionScore = 0;
        if (interactionHistory.length > 0) {
            for (uint256 i = 0; i < interactionHistory.length; i++) {
                interactionScore += interactionHistory[i];
            }
            interactionScore = interactionScore / interactionHistory.length;
        }

        uint256 consistencyBonus = relationship.interactionCount > 10 ?
            Aetherweb3Math.WAD / 10 : 0; // 10% bonus for consistent interactions

        trustScore = relationship.trustScore.wmul(recencyFactor)
            .wmul(interactionScore)
            .wdiv(Aetherweb3Math.WAD)
            + consistencyBonus;
    }

    /**
     * @dev Validates identity attribute
     * @param attribute Identity attribute
     * @param currentTime Current timestamp
     * @return isValid True if attribute is valid
     */
    function validateIdentityAttribute(
        Attribute memory attribute,
        uint256 currentTime
    ) internal pure returns (bool isValid) {
        if (attribute.issuer == address(0)) return false;
        if (attribute.issuanceTime > currentTime) return false;
        if (attribute.expirationTime > 0 && currentTime > attribute.expirationTime) return false;
        if (attribute.confidence == 0) return false;
        return true;
    }

    /**
     * @dev Calculates identity verification score
     * @param identity Identity information
     * @param verificationRequests Array of verification requests
     * @return verificationScore Verification score
     */
    function calculateVerificationScore(
        Identity memory identity,
        VerificationRequest[] memory verificationRequests
    ) internal pure returns (uint256 verificationScore) {
        uint256 baseScore = 0;

        // Base score from verification level
        if (identity.verificationLevel == VerificationLevel.BASIC) baseScore = 25;
        else if (identity.verificationLevel == VerificationLevel.INTERMEDIATE) baseScore = 50;
        else if (identity.verificationLevel == VerificationLevel.ADVANCED) baseScore = 75;
        else if (identity.verificationLevel == VerificationLevel.MAXIMUM) baseScore = 100;

        // Bonus from successful verifications
        uint256 successfulVerifications = 0;
        for (uint256 i = 0; i < verificationRequests.length; i++) {
            if (verificationRequests[i].status == VerificationStatus.APPROVED) {
                successfulVerifications++;
            }
        }

        uint256 verificationBonus = successfulVerifications * 5; // 5 points per successful verification
        verificationScore = Aetherweb3Math.min(baseScore + verificationBonus, 100);
    }

    /**
     * @dev Calculates reputation volatility
     * @param scores Array of historical reputation scores
     * @return volatility Reputation volatility
     */
    function calculateReputationVolatility(
        uint256[] memory scores
    ) internal pure returns (uint256 volatility) {
        if (scores.length < 2) return 0;

        uint256 sum = 0;
        uint256 mean = 0;

        // Calculate mean
        for (uint256 i = 0; i < scores.length; i++) {
            sum += scores[i];
        }
        mean = sum / scores.length;

        // Calculate variance
        uint256 variance = 0;
        for (uint256 i = 0; i < scores.length; i++) {
            uint256 diff = scores[i] > mean ? scores[i] - mean : mean - scores[i];
            variance += diff * diff;
        }
        variance = variance / scores.length;

        // Volatility as coefficient of variation
        if (mean == 0) return 0;
        volatility = Aetherweb3Math.sqrt(variance) * Aetherweb3Math.WAD / mean;
    }

    /**
     * @dev Calculates identity trust network
     * @param relationships Array of trust relationships
     * @param targetEntity Target entity
     * @param maxDepth Maximum network depth
     * @return networkTrust Network trust score
     */
    function calculateTrustNetwork(
        TrustRelationship[] memory relationships,
        address targetEntity,
        uint256 maxDepth
    ) internal pure returns (uint256 networkTrust) {
        uint256 totalTrust = 0;
        uint256 trustCount = 0;

        for (uint256 i = 0; i < relationships.length; i++) {
            if (relationships[i].trustee == targetEntity && relationships[i].active) {
                totalTrust += relationships[i].trustScore;
                trustCount++;
            }
        }

        if (trustCount == 0) return 0;

        // Apply network depth discount
        uint256 depthDiscount = Aetherweb3Math.WAD / (1 + maxDepth);
        networkTrust = (totalTrust / trustCount).wmul(depthDiscount);
    }

    /**
     * @dev Validates reputation event
     * @param event Reputation event
     * @param currentTime Current timestamp
     * @return isValid True if event is valid
     */
    function validateReputationEvent(
        ReputationEvent memory event,
        uint256 currentTime
    ) internal pure returns (bool isValid) {
        if (event.subject == address(0)) return false;
        if (event.issuer == address(0)) return false;
        if (event.timestamp > currentTime) return false;
        if (event.weight == 0) return false;
        return true;
    }

    /**
     * @dev Calculates identity similarity score
     * @param identity1 First identity
     * @param identity2 Second identity
     * @param attributeKeys Array of attribute keys to compare
     * @return similarityScore Similarity score (0-100)
     */
    function calculateIdentitySimilarity(
        Identity memory identity1,
        Identity memory identity2,
        bytes32[] memory attributeKeys
    ) internal pure returns (uint256 similarityScore) {
        if (attributeKeys.length == 0) return 0;

        uint256 matchingAttributes = 0;

        for (uint256 i = 0; i < attributeKeys.length; i++) {
            bytes32 key = attributeKeys[i];
            Attribute memory attr1 = identity1.attributes[key];
            Attribute memory attr2 = identity2.attributes[key];

            if (attr1.value == attr2.value && attr1.verified && attr2.verified) {
                matchingAttributes++;
            }
        }

        similarityScore = matchingAttributes * 100 / attributeKeys.length;
    }

    /**
     * @dev Calculates reputation consistency
     * @param events Array of reputation events
     * @param timeWindow Time window for analysis
     * @param currentTime Current timestamp
     * @return consistency Consistency score
     */
    function calculateReputationConsistency(
        ReputationEvent[] memory events,
        uint256 timeWindow,
        uint256 currentTime
    ) internal pure returns (uint256 consistency) {
        uint256 recentEvents = 0;
        uint256 positiveEvents = 0;
        uint256 negativeEvents = 0;

        for (uint256 i = 0; i < events.length; i++) {
            if (currentTime - events[i].timestamp <= timeWindow) {
                recentEvents++;
                if (events[i].scoreChange > 0) positiveEvents++;
                else if (events[i].scoreChange < 0) negativeEvents++;
            }
        }

        if (recentEvents == 0) return 50; // Neutral consistency

        uint256 positiveRatio = positiveEvents * Aetherweb3Math.WAD / recentEvents;
        uint256 negativeRatio = negativeEvents * Aetherweb3Math.WAD / recentEvents;

        // Consistency is higher when behavior is more predictable
        uint256 balance = positiveRatio > negativeRatio ?
            positiveRatio - negativeRatio :
            negativeRatio - positiveRatio;

        consistency = Aetherweb3Math.WAD - balance; // Higher balance = lower consistency
    }

    /**
     * @dev Checks for identity fraud indicators
     * @param identity Identity to check
     * @param events Array of reputation events
     * @param relationships Array of trust relationships
     * @return fraudScore Fraud risk score (0-100)
     */
    function checkFraudIndicators(
        Identity memory identity,
        ReputationEvent[] memory events,
        TrustRelationship[] memory relationships
    ) internal pure returns (uint256 fraudScore) {
        uint256 riskFactors = 0;

        // Check for sudden reputation changes
        uint256 volatility = calculateReputationVolatilityScore(events);
        if (volatility > 50 * Aetherweb3Math.WAD / 100) riskFactors += 20;

        // Check for low trust relationships
        uint256 lowTrustRelationships = 0;
        for (uint256 i = 0; i < relationships.length; i++) {
            if (relationships[i].trustScore < 30 * Aetherweb3Math.WAD / 100) {
                lowTrustRelationships++;
            }
        }
        if (lowTrustRelationships > relationships.length / 2) riskFactors += 15;

        // Check for expired attributes
        // Note: This would require iterating through attributes mapping
        // For now, we'll assume some risk if verification level is low
        if (identity.verificationLevel == VerificationLevel.NONE ||
            identity.verificationLevel == VerificationLevel.BASIC) {
            riskFactors += 10;
        }

        fraudScore = Aetherweb3Math.min(riskFactors, 100);
    }

    /**
     * @dev Calculates reputation volatility score
     * @param events Array of reputation events
     * @return volatility Volatility score
     */
    function calculateReputationVolatilityScore(
        ReputationEvent[] memory events
    ) internal pure returns (uint256 volatility) {
        if (events.length < 2) return 0;

        uint256[] memory scores = new uint256[](events.length);
        uint256 cumulativeScore = 0;

        for (uint256 i = 0; i < events.length; i++) {
            cumulativeScore = events[i].scoreChange >= 0 ?
                cumulativeScore + uint256(events[i].scoreChange) :
                cumulativeScore - uint256(-events[i].scoreChange);
            scores[i] = cumulativeScore;
        }

        return calculateReputationVolatility(scores);
    }

    /**
     * @dev Calculates identity age bonus
     * @param creationTime Identity creation time
     * @param currentTime Current timestamp
     * @return ageBonus Age bonus score
     */
    function calculateIdentityAgeBonus(
        uint256 creationTime,
        uint256 currentTime
    ) internal pure returns (uint256 ageBonus) {
        uint256 age = currentTime - creationTime;

        if (age < 30 days) ageBonus = 0;
        else if (age < 90 days) ageBonus = 10 * Aetherweb3Math.WAD / 100;
        else if (age < 180 days) ageBonus = 20 * Aetherweb3Math.WAD / 100;
        else if (age < 365 days) ageBonus = 30 * Aetherweb3Math.WAD / 100;
        else ageBonus = 50 * Aetherweb3Math.WAD / 100; // Max bonus for identities > 1 year
    }

    /**
     * @dev Validates trust relationship
     * @param relationship Trust relationship
     * @param currentTime Current timestamp
     * @return isValid True if relationship is valid
     */
    function validateTrustRelationship(
        TrustRelationship memory relationship,
        uint256 currentTime
    ) internal pure returns (bool isValid) {
        if (relationship.truster == address(0)) return false;
        if (relationship.trustee == address(0)) return false;
        if (relationship.establishedTime > currentTime) return false;
        if (relationship.trustScore == 0) return false;
        return true;
    }

    /**
     * @dev Calculates verification request priority
     * @param request Verification request
     * @param requesterReputation Requester reputation score
     * @param requestedLevel Requested verification level
     * @return priority Priority score
     */
    function calculateVerificationPriority(
        VerificationRequest memory request,
        uint256 requesterReputation,
        VerificationLevel requestedLevel
    ) internal pure returns (uint256 priority) {
        uint256 reputationFactor = requesterReputation / 10; // 0-10 points
        uint256 levelFactor = uint256(requestedLevel) * 5; // 0-20 points
        uint256 timeFactor = (block.timestamp - request.requestTime) / 1 days; // 1 point per day waiting

        priority = reputationFactor + levelFactor + timeFactor;
    }

    /**
     * @dev Calculates identity completeness score
     * @param identity Identity information
     * @param requiredAttributes Array of required attribute keys
     * @return completenessScore Completeness score (0-100)
     */
    function calculateIdentityCompleteness(
        Identity memory identity,
        bytes32[] memory requiredAttributes
    ) internal pure returns (uint256 completenessScore) {
        if (requiredAttributes.length == 0) return 100;

        uint256 completedAttributes = 0;

        for (uint256 i = 0; i < requiredAttributes.length; i++) {
            Attribute memory attr = identity.attributes[requiredAttributes[i]];
            if (attr.value != bytes32(0) && attr.verified) {
                completedAttributes++;
            }
        }

        completenessScore = completedAttributes * 100 / requiredAttributes.length;
    }
}
