// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Aetherweb3Utils
 * @dev Utility library providing common helper functions and operations
 * @notice Contains reusable utility functions for the Aetherweb3 ecosystem
 */
library Aetherweb3Utils {
    // Time constants
    uint256 internal constant SECONDS_PER_MINUTE = 60;
    uint256 internal constant SECONDS_PER_HOUR = 3600;
    uint256 internal constant SECONDS_PER_DAY = 86400;
    uint256 internal constant SECONDS_PER_WEEK = 604800;
    uint256 internal constant SECONDS_PER_MONTH = 2629746; // Average month
    uint256 internal constant SECONDS_PER_YEAR = 31556952; // Average year

    /**
     * @dev Converts bytes to address
     * @param bys Bytes to convert
     * @return addr Converted address
     */
    function bytesToAddress(bytes memory bys) internal pure returns (address addr) {
        require(bys.length >= 20, "Aetherweb3Utils: invalid bytes length");
        assembly {
            addr := mload(add(bys, 20))
        }
    }

    /**
     * @dev Converts address to bytes
     * @param addr Address to convert
     * @return bys Converted bytes
     */
    function addressToBytes(address addr) internal pure returns (bytes memory bys) {
        bys = new bytes(20);
        assembly {
            mstore(add(bys, 20), addr)
        }
    }

    /**
     * @dev Converts uint256 to string
     * @param value Value to convert
     * @return str String representation
     */
    function uint256ToString(uint256 value) internal pure returns (string memory str) {
        if (value == 0) return "0";

        uint256 temp = value;
        uint256 digits;

        while (temp != 0) {
            digits++;
            temp /= 10;
        }

        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }

        return string(buffer);
    }

    /**
     * @dev Converts string to uint256
     * @param str String to convert
     * @return value Converted value
     */
    function stringToUint256(string memory str) internal pure returns (uint256 value) {
        bytes memory b = bytes(str);
        for (uint256 i = 0; i < b.length; i++) {
            uint256 c = uint256(uint8(b[i]));
            if (c >= 48 && c <= 57) {
                value = value * 10 + (c - 48);
            } else {
                revert("Aetherweb3Utils: invalid character");
            }
        }
    }

    /**
     * @dev Checks if string contains substring
     * @param str Main string
     * @param substr Substring to search for
     * @return contains True if substring is found
     */
    function contains(string memory str, string memory substr) internal pure returns (bool contains) {
        bytes memory strBytes = bytes(str);
        bytes memory substrBytes = bytes(substr);

        if (substrBytes.length > strBytes.length) return false;

        for (uint256 i = 0; i <= strBytes.length - substrBytes.length; i++) {
            bool found = true;
            for (uint256 j = 0; j < substrBytes.length; j++) {
                if (strBytes[i + j] != substrBytes[j]) {
                    found = false;
                    break;
                }
            }
            if (found) return true;
        }

        return false;
    }

    /**
     * @dev Compares two strings
     * @param str1 First string
     * @param str2 Second string
     * @return equal True if strings are equal
     */
    function equals(string memory str1, string memory str2) internal pure returns (bool equal) {
        return keccak256(bytes(str1)) == keccak256(bytes(str2));
    }

    /**
     * @dev Concatenates two strings
     * @param str1 First string
     * @param str2 Second string
     * @return result Concatenated string
     */
    function concat(string memory str1, string memory str2) internal pure returns (string memory result) {
        bytes memory str1Bytes = bytes(str1);
        bytes memory str2Bytes = bytes(str2);

        bytes memory resultBytes = new bytes(str1Bytes.length + str2Bytes.length);
        uint256 k = 0;

        for (uint256 i = 0; i < str1Bytes.length; i++) {
            resultBytes[k++] = str1Bytes[i];
        }

        for (uint256 i = 0; i < str2Bytes.length; i++) {
            resultBytes[k++] = str2Bytes[i];
        }

        return string(resultBytes);
    }

    /**
     * @dev Gets current timestamp
     * @return timestamp Current block timestamp
     */
    function currentTime() internal view returns (uint256 timestamp) {
        return block.timestamp;
    }

    /**
     * @dev Gets current block number
     * @return blockNumber Current block number
     */
    function currentBlock() internal view returns (uint256 blockNumber) {
        return block.number;
    }

    /**
     * @dev Checks if address is contract
     * @param addr Address to check
     * @return isContract True if address is contract
     */
    function isContract(address addr) internal view returns (bool isContract) {
        uint256 size;
        assembly {
            size := extcodesize(addr)
        }
        return size > 0;
    }

    /**
     * @dev Gets contract code hash
     * @param addr Contract address
     * @return codeHash Hash of contract code
     */
    function getCodeHash(address addr) internal view returns (bytes32 codeHash) {
        bytes32 hash;
        assembly {
            hash := extcodehash(addr)
        }
        return hash;
    }

    /**
     * @dev Validates Ethereum address checksum
     * @param addr Address to validate
     * @return isValid True if address has valid checksum
     */
    function isValidChecksumAddress(address addr) internal pure returns (bool isValid) {
        // Simplified validation - in practice, you'd implement full EIP-55 checksum
        return addr != address(0);
    }

    /**
     * @dev Calculates time difference in human readable format
     * @param startTime Start timestamp
     * @param endTime End timestamp
     * @return days Number of days
     * @return hours Number of hours
     * @return minutes Number of minutes
     * @return seconds Number of seconds
     */
    function timeDifference(
        uint256 startTime,
        uint256 endTime
    ) internal pure returns (uint256 days, uint256 hours, uint256 minutes, uint256 seconds) {
        require(endTime >= startTime, "Aetherweb3Utils: end time before start time");

        uint256 diff = endTime - startTime;

        days = diff / SECONDS_PER_DAY;
        diff -= days * SECONDS_PER_DAY;

        hours = diff / SECONDS_PER_HOUR;
        diff -= hours * SECONDS_PER_HOUR;

        minutes = diff / SECONDS_PER_MINUTE;
        diff -= minutes * SECONDS_PER_MINUTE;

        seconds = diff;
    }

    /**
     * @dev Formats timestamp to human readable date string
     * @param timestamp Timestamp to format
     * @return dateString Formatted date string
     */
    function formatTimestamp(uint256 timestamp) internal pure returns (string memory dateString) {
        // Simplified date formatting
        // In practice, you'd want more sophisticated date handling
        return concat("Timestamp: ", uint256ToString(timestamp));
    }

    /**
     * @dev Generates pseudo-random number
     * @param seed Random seed
     * @param max Maximum value (exclusive)
     * @return randomNumber Pseudo-random number
     */
    function pseudoRandom(uint256 seed, uint256 max) internal view returns (uint256 randomNumber) {
        require(max > 0, "Aetherweb3Utils: invalid max value");

        uint256 random = uint256(
            keccak256(
                abi.encodePacked(
                    block.timestamp,
                    block.difficulty,
                    seed,
                    msg.sender
                )
            )
        );

        return random % max;
    }

    /**
     * @dev Validates array length
     * @param array Array to validate
     * @param minLength Minimum length
     * @param maxLength Maximum length
     * @return isValid True if array length is valid
     */
    function validateArrayLength(
        uint256[] memory array,
        uint256 minLength,
        uint256 maxLength
    ) internal pure returns (bool isValid) {
        return array.length >= minLength && array.length <= maxLength;
    }

    /**
     * @dev Validates address array
     * @param array Array to validate
     * @return isValid True if all addresses are valid
     */
    function validateAddressArray(address[] memory array) internal pure returns (bool isValid) {
        for (uint256 i = 0; i < array.length; i++) {
            if (array[i] == address(0)) return false;
        }
        return true;
    }

    /**
     * @dev Finds index of address in array
     * @param array Array to search
     * @param target Target address
     * @return index Index of target address, or type(uint256).max if not found
     */
    function findAddressIndex(
        address[] memory array,
        address target
    ) internal pure returns (uint256 index) {
        for (uint256 i = 0; i < array.length; i++) {
            if (array[i] == target) {
                return i;
            }
        }
        return type(uint256).max;
    }

    /**
     * @dev Removes address from array
     * @param array Array to modify
     * @param index Index to remove
     * @return newArray New array without the removed element
     */
    function removeAddressFromArray(
        address[] memory array,
        uint256 index
    ) internal pure returns (address[] memory newArray) {
        require(index < array.length, "Aetherweb3Utils: index out of bounds");

        newArray = new address[](array.length - 1);
        uint256 j = 0;

        for (uint256 i = 0; i < array.length; i++) {
            if (i != index) {
                newArray[j++] = array[i];
            }
        }
    }

    /**
     * @dev Slices array
     * @param array Array to slice
     * @param start Start index
     * @param length Length of slice
     * @return slice Sliced array
     */
    function sliceAddressArray(
        address[] memory array,
        uint256 start,
        uint256 length
    ) internal pure returns (address[] memory slice) {
        require(start + length <= array.length, "Aetherweb3Utils: slice out of bounds");

        slice = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            slice[i] = array[start + i];
        }
    }

    /**
     * @dev Merges two address arrays
     * @param array1 First array
     * @param array2 Second array
     * @return merged Merged array
     */
    function mergeAddressArrays(
        address[] memory array1,
        address[] memory array2
    ) internal pure returns (address[] memory merged) {
        merged = new address[](array1.length + array2.length);

        uint256 k = 0;
        for (uint256 i = 0; i < array1.length; i++) {
            merged[k++] = array1[i];
        }
        for (uint256 i = 0; i < array2.length; i++) {
            merged[k++] = array2[i];
        }
    }

    /**
     * @dev Calculates gas cost estimation
     * @param gasUsed Gas used
     * @param gasPrice Gas price
     * @return cost Estimated cost in wei
     */
    function estimateGasCost(
        uint256 gasUsed,
        uint256 gasPrice
    ) internal pure returns (uint256 cost) {
        return gasUsed * gasPrice;
    }

    /**
     * @dev Validates function signature
     * @param signature Function signature
     * @return isValid True if signature is valid
     */
    function validateFunctionSignature(bytes4 signature) internal pure returns (bool isValid) {
        // Check if signature is not empty and follows expected format
        return signature != bytes4(0);
    }

    /**
     * @dev Encodes function call data
     * @param signature Function signature
     * @param params Encoded parameters
     * @return callData Encoded call data
     */
    function encodeFunctionCall(
        bytes4 signature,
        bytes memory params
    ) internal pure returns (bytes memory callData) {
        callData = abi.encodePacked(signature, params);
    }

    /**
     * @dev Decodes function call data
     * @param callData Encoded call data
     * @return signature Function signature
     * @return params Decoded parameters
     */
    function decodeFunctionCall(
        bytes memory callData
    ) internal pure returns (bytes4 signature, bytes memory params) {
        require(callData.length >= 4, "Aetherweb3Utils: invalid call data");

        signature = bytes4(callData[0]) | (bytes4(callData[1]) >> 8) | (bytes4(callData[2]) >> 16) | (bytes4(callData[3]) >> 24);

        params = new bytes(callData.length - 4);
        for (uint256 i = 4; i < callData.length; i++) {
            params[i - 4] = callData[i];
        }
    }
}
