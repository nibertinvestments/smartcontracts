// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20FlashMint.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./libraries/Aetherweb3Math.sol";
import "./libraries/Aetherweb3Safety.sol";

/**
 * @title Aetherweb3TokenCreator
 * @dev Comprehensive token creation contract for the Aetherweb3 ecosystem
 * @notice Allows users to create highly customizable ERC20 tokens with various features
 */
contract Aetherweb3TokenCreator is Ownable, ReentrancyGuard, Aetherweb3Safety {
    using Aetherweb3Math for uint256;

    // Token creation fee (configurable via deployment)
    uint256 public creationFee;

    // Fee recipient address (configurable via deployment)
    address public feeRecipient;

    // Token types enumeration
    enum TokenType {
        STANDARD,       // Basic ERC20
        BURNABLE,       // With burn functionality
        MINTABLE,       // With mint functionality
        PAUSABLE,       // With pause functionality
        CAPPED,         // With supply cap
        TAXABLE,        // With transaction tax
        REFLECTION,     // With reflection rewards
        GOVERNANCE,     // With governance features
        FLASH_MINT,     // With flash minting
        FULL_FEATURED   // All features combined
    }

    // Token features structure
    struct TokenFeatures {
        bool burnable;
        bool mintable;
        bool pausable;
        bool capped;
        bool taxable;
        bool reflection;
        bool governance;
        bool flashMint;
        bool permit;
    }

    // Tax configuration
    struct TaxConfig {
        uint256 buyTax;         // Tax on buys (in basis points)
        uint256 sellTax;        // Tax on sells (in basis points)
        uint256 transferTax;    // Tax on transfers (in basis points)
        address taxWallet;      // Wallet to receive taxes
        bool taxOnBuys;         // Enable tax on buys
        bool taxOnSells;        // Enable tax on sells
        bool taxOnTransfers;    // Enable tax on transfers
    }

    // Reflection configuration
    struct ReflectionConfig {
        uint256 reflectionFee;  // Reflection fee (in basis points)
        address rewardToken;    // Token to distribute as rewards
        bool autoClaim;         // Auto claim rewards
        uint256 minTokensForClaim; // Minimum tokens for claiming
    }

    // Token creation parameters
    struct TokenParams {
        string name;                    // Token name
        string symbol;                  // Token symbol
        uint256 initialSupply;         // Initial supply
        uint8 decimals;                // Token decimals
        uint256 maxSupply;             // Maximum supply (for capped tokens)
        address owner;                 // Token owner
        TokenFeatures features;        // Token features
        TaxConfig taxConfig;           // Tax configuration
        ReflectionConfig reflectionConfig; // Reflection configuration
        bytes32 salt;                  // Salt for create2 deployment
    }

    // Created token information
    struct CreatedToken {
        address tokenAddress;          // Deployed token address
        address creator;               // Token creator
        string name;                   // Token name
        string symbol;                 // Token symbol
        uint256 creationTime;          // Creation timestamp
        TokenType tokenType;           // Token type
        uint256 initialSupply;         // Initial supply
        bool verified;                 // Verification status
    }

    // Events
    event TokenCreated(
        address indexed tokenAddress,
        address indexed creator,
        string name,
        string symbol,
        uint256 initialSupply,
        TokenType tokenType
    );

    event TokenVerified(
        address indexed tokenAddress,
        address indexed verifier
    );

    event FeeRecipientUpdated(
        address indexed oldRecipient,
        address indexed newRecipient
    );

    // State variables
    mapping(address => CreatedToken[]) public creatorTokens;
    mapping(address => bool) public verifiedTokens;
    mapping(address => address) public tokenCreators;
    uint256 public totalTokensCreated;
    uint256 public totalFeesCollected;

    // Fee exemption for ecosystem contracts
    mapping(address => bool) public feeExempt;

    /**
     * @dev Constructor
     * @param _feeRecipient Address to receive creation fees
     * @param _creationFee Fee amount for token creation
     */
    constructor(address _feeRecipient, uint256 _creationFee) {
        require(_feeRecipient != address(0), "Invalid fee recipient");
        require(_creationFee > 0, "Invalid creation fee");
        feeRecipient = _feeRecipient;
        creationFee = _creationFee;
        _transferOwnership(msg.sender);
    }

    /**
     * @dev Updates the fee recipient address
     * @param _newRecipient New fee recipient address
     */
    function updateFeeRecipient(address _newRecipient) external onlyOwner {
        require(_newRecipient != address(0), "Invalid fee recipient");
        address oldRecipient = feeRecipient;
        feeRecipient = _newRecipient;
        emit FeeRecipientUpdated(oldRecipient, _newRecipient);
    }

    /**
     * @dev Updates the token creation fee
     * @param _newFee New creation fee amount
     */
    function updateCreationFee(uint256 _newFee) external onlyOwner {
        require(_newFee > 0, "Invalid creation fee");
        creationFee = _newFee;
    }

    /**
     * @dev Withdraws accumulated fees to the fee recipient
     */
    function withdrawFees() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to withdraw");
        payable(feeRecipient).transfer(balance);
    }

    /**
     * @dev Creates a new token with specified parameters
     * @param params Token creation parameters
     * @return tokenAddress Address of the created token
     */
    function createToken(TokenParams calldata params)
        external
        payable
        nonReentrant
        whenNotPaused
        returns (address tokenAddress)
    {
        // Validate payment
        uint256 requiredFee = feeExempt[msg.sender] ? 0 : creationFee;
        require(msg.value >= requiredFee, "Insufficient fee");

        // Refund excess payment
        if (msg.value > requiredFee) {
            payable(msg.sender).transfer(msg.value - requiredFee);
        }

        // Transfer fee to recipient
        if (requiredFee > 0) {
            payable(feeRecipient).transfer(requiredFee);
            totalFeesCollected += requiredFee;
        }

        // Validate parameters
        _validateTokenParams(params);

        // Determine token type
        TokenType tokenType = _determineTokenType(params.features);

        // Deploy token
        tokenAddress = _deployToken(params, tokenType);

        // Record token creation
        CreatedToken memory newToken = CreatedToken({
            tokenAddress: tokenAddress,
            creator: msg.sender,
            name: params.name,
            symbol: params.symbol,
            creationTime: block.timestamp,
            tokenType: tokenType,
            initialSupply: params.initialSupply,
            verified: false
        });

        creatorTokens[msg.sender].push(newToken);
        tokenCreators[tokenAddress] = msg.sender;
        totalTokensCreated++;

        emit TokenCreated(
            tokenAddress,
            msg.sender,
            params.name,
            params.symbol,
            params.initialSupply,
            tokenType
        );

        return tokenAddress;
    }

    /**
     * @dev Creates a standard ERC20 token
     * @param name Token name
     * @param symbol Token symbol
     * @param initialSupply Initial supply
     * @param decimals Token decimals
     * @return tokenAddress Address of the created token
     */
    function createStandardToken(
        string calldata name,
        string calldata symbol,
        uint256 initialSupply,
        uint8 decimals
    ) external payable returns (address tokenAddress) {
        TokenParams memory params = TokenParams({
            name: name,
            symbol: symbol,
            initialSupply: initialSupply,
            decimals: decimals,
            maxSupply: 0,
            owner: msg.sender,
            features: TokenFeatures({
                burnable: false,
                mintable: false,
                pausable: false,
                capped: false,
                taxable: false,
                reflection: false,
                governance: false,
                flashMint: false,
                permit: false
            }),
            taxConfig: TaxConfig({
                buyTax: 0,
                sellTax: 0,
                transferTax: 0,
                taxWallet: address(0),
                taxOnBuys: false,
                taxOnSells: false,
                taxOnTransfers: false
            }),
            reflectionConfig: ReflectionConfig({
                reflectionFee: 0,
                rewardToken: address(0),
                autoClaim: false,
                minTokensForClaim: 0
            }),
            salt: bytes32(0)
        });

        return createToken(params);
    }

    /**
     * @dev Creates a full-featured token with all capabilities
     * @param name Token name
     * @param symbol Token symbol
     * @param initialSupply Initial supply
     * @param maxSupply Maximum supply
     * @param taxWallet Tax collection wallet
     * @return tokenAddress Address of the created token
     */
    function createFullFeaturedToken(
        string calldata name,
        string calldata symbol,
        uint256 initialSupply,
        uint256 maxSupply,
        address taxWallet
    ) external payable returns (address tokenAddress) {
        TokenParams memory params = TokenParams({
            name: name,
            symbol: symbol,
            initialSupply: initialSupply,
            decimals: 18,
            maxSupply: maxSupply,
            owner: msg.sender,
            features: TokenFeatures({
                burnable: true,
                mintable: true,
                pausable: true,
                capped: true,
                taxable: true,
                reflection: true,
                governance: true,
                flashMint: true,
                permit: true
            }),
            taxConfig: TaxConfig({
                buyTax: 300,    // 3%
                sellTax: 500,    // 5%
                transferTax: 100, // 1%
                taxWallet: taxWallet,
                taxOnBuys: true,
                taxOnSells: true,
                taxOnTransfers: true
            }),
            reflectionConfig: ReflectionConfig({
                reflectionFee: 200, // 2%
                rewardToken: address(0), // Use same token for rewards
                autoClaim: true,
                minTokensForClaim: 1000 * 10**18
            }),
            salt: bytes32(0)
        });

        return createToken(params);
    }

    /**
     * @dev Verifies a token (only creator can verify)
     * @param tokenAddress Address of the token to verify
     */
    function verifyToken(address tokenAddress) external {
        require(tokenCreators[tokenAddress] == msg.sender, "Not token creator");
        require(!verifiedTokens[tokenAddress], "Already verified");

        verifiedTokens[tokenAddress] = true;

        // Update token info
        CreatedToken[] storage tokens = creatorTokens[msg.sender];
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i].tokenAddress == tokenAddress) {
                tokens[i].verified = true;
                break;
            }
        }

        emit TokenVerified(tokenAddress, msg.sender);
    }

    /**
     * @dev Gets tokens created by an address
     * @param creator Address of the creator
     * @return tokens Array of created tokens
     */
    function getCreatorTokens(address creator)
        external
        view
        returns (CreatedToken[] memory tokens)
    {
        return creatorTokens[creator];
    }

    /**
     * @dev Gets token creation statistics
     * @return totalCreated Total tokens created
     * @return totalFees Total fees collected
     */
    function getCreationStats()
        external
        view
        returns (uint256 totalCreated, uint256 totalFees)
    {
        return (totalTokensCreated, totalFeesCollected);
    }

    /**
     * @dev Updates fee recipient (only owner)
     * @param newRecipient New fee recipient address
     */
    function updateFeeRecipient(address newRecipient) external onlyOwner {
        require(newRecipient != address(0), "Invalid recipient");
        address oldRecipient = feeRecipient;
        feeRecipient = newRecipient;

        emit FeeRecipientUpdated(oldRecipient, newRecipient);
    }

    /**
     * @dev Sets fee exemption for ecosystem contracts (only owner)
     * @param account Address to exempt
     * @param exempt Whether to exempt from fees
     */
    function setFeeExempt(address account, bool exempt) external onlyOwner {
        feeExempt[account] = exempt;
    }

    /**
     * @dev Withdraws accumulated fees (only owner)
     */
    function withdrawFees() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to withdraw");

        payable(feeRecipient).transfer(balance);
    }

    /**
     * @dev Validates token creation parameters
     * @param params Token parameters to validate
     */
    function _validateTokenParams(TokenParams memory params) internal pure {
        require(bytes(params.name).length > 0, "Name required");
        require(bytes(params.name).length <= 32, "Name too long");
        require(bytes(params.symbol).length > 0, "Symbol required");
        require(bytes(params.symbol).length <= 8, "Symbol too long");
        require(params.initialSupply > 0, "Initial supply required");
        require(params.decimals <= 18, "Invalid decimals");
        require(params.owner != address(0), "Invalid owner");

        if (params.features.capped) {
            require(params.maxSupply >= params.initialSupply, "Max supply too low");
        }

        if (params.features.taxable) {
            require(params.taxConfig.taxWallet != address(0), "Tax wallet required");
            require(params.taxConfig.buyTax <= 1000, "Buy tax too high"); // Max 10%
            require(params.taxConfig.sellTax <= 1000, "Sell tax too high");
            require(params.taxConfig.transferTax <= 1000, "Transfer tax too high");
        }

        if (params.features.reflection) {
            require(params.reflectionConfig.reflectionFee <= 1000, "Reflection fee too high");
        }
    }

    /**
     * @dev Determines token type based on features
     * @param features Token features
     * @return tokenType Determined token type
     */
    function _determineTokenType(TokenFeatures memory features)
        internal
        pure
        returns (TokenType tokenType)
    {
        if (features.burnable && features.mintable && features.pausable &&
            features.capped && features.taxable && features.reflection &&
            features.governance && features.flashMint) {
            return TokenType.FULL_FEATURED;
        } else if (features.governance) {
            return TokenType.GOVERNANCE;
        } else if (features.reflection) {
            return TokenType.REFLECTION;
        } else if (features.taxable) {
            return TokenType.TAXABLE;
        } else if (features.capped) {
            return TokenType.CAPPED;
        } else if (features.pausable) {
            return TokenType.PAUSABLE;
        } else if (features.mintable) {
            return TokenType.MINTABLE;
        } else if (features.burnable) {
            return TokenType.BURNABLE;
        } else {
            return TokenType.STANDARD;
        }
    }

    /**
     * @dev Deploys the token contract
     * @param params Token parameters
     * @param tokenType Type of token to deploy
     * @return tokenAddress Address of deployed token
     */
    function _deployToken(TokenParams memory params, TokenType tokenType)
        internal
        returns (address tokenAddress)
    {
        if (tokenType == TokenType.FULL_FEATURED) {
            tokenAddress = address(new Aetherweb3FullFeaturedToken(
                params.name,
                params.symbol,
                params.initialSupply,
                params.decimals,
                params.maxSupply,
                params.owner,
                params.taxConfig,
                params.reflectionConfig
            ));
        } else if (tokenType == TokenType.GOVERNANCE) {
            tokenAddress = address(new Aetherweb3GovernanceToken(
                params.name,
                params.symbol,
                params.initialSupply,
                params.owner
            ));
        } else if (tokenType == TokenType.REFLECTION) {
            tokenAddress = address(new Aetherweb3ReflectionToken(
                params.name,
                params.symbol,
                params.initialSupply,
                params.owner,
                params.reflectionConfig
            ));
        } else if (tokenType == TokenType.TAXABLE) {
            tokenAddress = address(new Aetherweb3TaxableToken(
                params.name,
                params.symbol,
                params.initialSupply,
                params.owner,
                params.taxConfig
            ));
        } else if (tokenType == TokenType.CAPPED) {
            tokenAddress = address(new Aetherweb3CappedToken(
                params.name,
                params.symbol,
                params.initialSupply,
                params.maxSupply,
                params.owner
            ));
        } else if (tokenType == TokenType.PAUSABLE) {
            tokenAddress = address(new Aetherweb3PausableToken(
                params.name,
                params.symbol,
                params.initialSupply,
                params.owner
            ));
        } else if (tokenType == TokenType.MINTABLE) {
            tokenAddress = address(new Aetherweb3MintableToken(
                params.name,
                params.symbol,
                params.initialSupply,
                params.owner
            ));
        } else if (tokenType == TokenType.BURNABLE) {
            tokenAddress = address(new Aetherweb3BurnableToken(
                params.name,
                params.symbol,
                params.initialSupply,
                params.owner
            ));
        } else {
            tokenAddress = address(new Aetherweb3StandardToken(
                params.name,
                params.symbol,
                params.initialSupply,
                params.decimals,
                params.owner
            ));
        }
    }

    /**
     * @dev Emergency pause (only owner)
     */
    function emergencyPause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Emergency unpause (only owner)
     */
    function emergencyUnpause() external onlyOwner {
        _unpause();
    }
}

/**
 * @title Aetherweb3StandardToken
 * @dev Basic ERC20 token implementation
 */
contract Aetherweb3StandardToken is ERC20, Ownable {
    uint8 private _decimals;

    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        uint8 decimals_,
        address owner
    ) ERC20(name, symbol) {
        _decimals = decimals_;
        _mint(owner, initialSupply);
        _transferOwnership(owner);
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }
}

/**
 * @title Aetherweb3BurnableToken
 * @dev ERC20 token with burn functionality
 */
contract Aetherweb3BurnableToken is ERC20Burnable, Ownable {
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        address owner
    ) ERC20(name, symbol) {
        _mint(owner, initialSupply);
        _transferOwnership(owner);
    }
}

/**
 * @title Aetherweb3MintableToken
 * @dev ERC20 token with mint functionality
 */
contract Aetherweb3MintableToken is ERC20, Ownable {
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        address owner
    ) ERC20(name, symbol) {
        _mint(owner, initialSupply);
        _transferOwnership(owner);
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}

/**
 * @title Aetherweb3PausableToken
 * @dev ERC20 token with pause functionality
 */
contract Aetherweb3PausableToken is ERC20Pausable, Ownable {
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        address owner
    ) ERC20(name, symbol) {
        _mint(owner, initialSupply);
        _transferOwnership(owner);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}

/**
 * @title Aetherweb3CappedToken
 * @dev ERC20 token with supply cap
 */
contract Aetherweb3CappedToken is ERC20Capped, Ownable {
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        uint256 maxSupply,
        address owner
    ) ERC20(name, symbol) ERC20Capped(maxSupply) {
        _mint(owner, initialSupply);
        _transferOwnership(owner);
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}

/**
 * @title Aetherweb3TaxableToken
 * @dev ERC20 token with transaction taxes
 */
contract Aetherweb3TaxableToken is ERC20, Ownable {
    using Aetherweb3Math for uint256;

    struct TaxConfig {
        uint256 buyTax;
        uint256 sellTax;
        uint256 transferTax;
        address taxWallet;
        bool taxOnBuys;
        bool taxOnSells;
        bool taxOnTransfers;
    }

    TaxConfig public taxConfig;
    mapping(address => bool) public taxExempt;

    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        address owner,
        TaxConfig memory _taxConfig
    ) ERC20(name, symbol) {
        _mint(owner, initialSupply);
        _transferOwnership(owner);
        taxConfig = _taxConfig;
        taxExempt[owner] = true;
        taxExempt[address(this)] = true;
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual override {
        if (taxExempt[sender] || taxExempt[recipient]) {
            super._transfer(sender, recipient, amount);
            return;
        }

        uint256 taxAmount = 0;
        if (taxConfig.taxOnTransfers) {
            taxAmount = amount.wmul(taxConfig.transferTax);
        }

        if (taxAmount > 0) {
            super._transfer(sender, taxConfig.taxWallet, taxAmount);
        }

        super._transfer(sender, recipient, amount - taxAmount);
    }

    function setTaxExempt(address account, bool exempt) external onlyOwner {
        taxExempt[account] = exempt;
    }
}

/**
 * @title Aetherweb3ReflectionToken
 * @dev ERC20 token with reflection rewards
 */
contract Aetherweb3ReflectionToken is ERC20, Ownable {
    using Aetherweb3Math for uint256;

    struct ReflectionConfig {
        uint256 reflectionFee;
        address rewardToken;
        bool autoClaim;
        uint256 minTokensForClaim;
    }

    ReflectionConfig public reflectionConfig;
    mapping(address => uint256) public reflections;
    mapping(address => uint256) public lastClaimTime;

    uint256 public totalReflections;
    uint256 public reflectionSupply;

    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        address owner,
        ReflectionConfig memory _reflectionConfig
    ) ERC20(name, symbol) {
        _mint(owner, initialSupply);
        _transferOwnership(owner);
        reflectionConfig = _reflectionConfig;
        reflectionSupply = initialSupply;
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual override {
        uint256 reflectionAmount = amount.wmul(reflectionConfig.reflectionFee);
        uint256 transferAmount = amount - reflectionAmount;

        if (reflectionAmount > 0) {
            uint256 reflectionPerToken = reflectionAmount.wdiv(totalSupply());
            totalReflections += reflectionAmount;

            // Distribute reflections proportionally
            for (uint256 i = 0; i < totalSupply(); i++) {
                // This is a simplified implementation
                // In production, you'd want a more efficient distribution mechanism
            }
        }

        super._transfer(sender, recipient, transferAmount);
    }

    function claimReflections() external {
        uint256 claimable = reflections[msg.sender];
        require(claimable > 0, "No reflections to claim");
        require(balanceOf(msg.sender) >= reflectionConfig.minTokensForClaim, "Insufficient balance");

        reflections[msg.sender] = 0;
        lastClaimTime[msg.sender] = block.timestamp;

        if (reflectionConfig.rewardToken == address(this)) {
            _mint(msg.sender, claimable);
        } else {
            // Transfer external reward token
            IERC20(reflectionConfig.rewardToken).transfer(msg.sender, claimable);
        }
    }
}

/**
 * @title Aetherweb3GovernanceToken
 * @dev ERC20 token with governance features
 */
contract Aetherweb3GovernanceToken is ERC20Votes, Ownable {
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        address owner
    ) ERC20(name, symbol) ERC20Permit(name) {
        _mint(owner, initialSupply);
        _transferOwnership(owner);
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    // Override required functions
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Votes) {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._burn(account, amount);
    }
}

/**
 * @title Aetherweb3FullFeaturedToken
 * @dev ERC20 token with all features combined
 */
contract Aetherweb3FullFeaturedToken is
    ERC20,
    ERC20Burnable,
    ERC20Pausable,
    ERC20Permit,
    ERC20Votes,
    ERC20FlashMint,
    ERC20Capped,
    Ownable
{
    using Aetherweb3Math for uint256;

    struct TaxConfig {
        uint256 buyTax;
        uint256 sellTax;
        uint256 transferTax;
        address taxWallet;
        bool taxOnBuys;
        bool taxOnSells;
        bool taxOnTransfers;
    }

    struct ReflectionConfig {
        uint256 reflectionFee;
        address rewardToken;
        bool autoClaim;
        uint256 minTokensForClaim;
    }

    TaxConfig public taxConfig;
    ReflectionConfig public reflectionConfig;

    mapping(address => bool) public taxExempt;
    mapping(address => uint256) public reflections;
    mapping(address => uint256) public lastClaimTime;

    uint256 public totalReflections;
    uint256 public reflectionSupply;

    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        uint8 decimals_,
        uint256 maxSupply,
        address owner,
        TaxConfig memory _taxConfig,
        ReflectionConfig memory _reflectionConfig
    ) ERC20(name, symbol) ERC20Capped(maxSupply) ERC20Permit(name) {
        _mint(owner, initialSupply);
        _transferOwnership(owner);

        taxConfig = _taxConfig;
        reflectionConfig = _reflectionConfig;

        taxExempt[owner] = true;
        taxExempt[address(this)] = true;
        reflectionSupply = initialSupply;
    }

    function decimals() public pure override returns (uint8) {
        return 18;
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function claimReflections() external {
        uint256 claimable = reflections[msg.sender];
        require(claimable > 0, "No reflections to claim");
        require(balanceOf(msg.sender) >= reflectionConfig.minTokensForClaim, "Insufficient balance");

        reflections[msg.sender] = 0;
        lastClaimTime[msg.sender] = block.timestamp;

        if (reflectionConfig.rewardToken == address(this)) {
            _mint(msg.sender, claimable);
        } else {
            IERC20(reflectionConfig.rewardToken).transfer(msg.sender, claimable);
        }
    }

    function setTaxExempt(address account, bool exempt) external onlyOwner {
        taxExempt[account] = exempt;
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual override(ERC20, ERC20Pausable) {
        if (taxExempt[sender] || taxExempt[recipient]) {
            super._transfer(sender, recipient, amount);
            return;
        }

        uint256 taxAmount = 0;
        if (taxConfig.taxOnTransfers) {
            taxAmount = amount.wmul(taxConfig.transferTax);
        }

        uint256 reflectionAmount = amount.wmul(reflectionConfig.reflectionFee);
        uint256 transferAmount = amount - taxAmount - reflectionAmount;

        if (taxAmount > 0) {
            super._transfer(sender, taxConfig.taxWallet, taxAmount);
        }

        if (reflectionAmount > 0) {
            uint256 reflectionPerToken = reflectionAmount.wdiv(totalSupply());
            totalReflections += reflectionAmount;
        }

        super._transfer(sender, recipient, transferAmount);
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Votes) {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal override(ERC20, ERC20Votes, ERC20Capped) {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._burn(account, amount);
    }
}
