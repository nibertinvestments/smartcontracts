// Aetherweb3 DApp JavaScript
class Aetherweb3DApp {
    constructor() {
        this.web3 = null;
        this.account = null;
        this.networkId = null;
        this.contracts = {};
        this.isConnected = false;

        this.init();
    }

    async init() {
        // Check if MetaMask is installed
        if (typeof window.ethereum !== 'undefined') {
            this.web3 = new Web3(window.ethereum);
            this.setupEventListeners();
            await this.checkConnection();
        } else {
            this.showNotification('Please install MetaMask to use this DApp', 'warning');
        }
    }

    setupEventListeners() {
        // Account changed
        window.ethereum.on('accountsChanged', (accounts) => {
            if (accounts.length > 0) {
                this.account = accounts[0];
                this.updateUI();
            } else {
                this.disconnect();
            }
        });

        // Network changed
        window.ethereum.on('chainChanged', (chainId) => {
            window.location.reload();
        });
    }

    async connectWallet() {
        try {
            const accounts = await window.ethereum.request({ method: 'eth_requestAccounts' });
            this.account = accounts[0];
            this.networkId = await this.web3.eth.net.getId();
            this.isConnected = true;
            this.updateUI();
            this.showNotification('Wallet connected successfully!', 'success');
        } catch (error) {
            console.error('Error connecting wallet:', error);
            this.showNotification('Error connecting wallet: ' + error.message, 'error');
        }
    }

    disconnect() {
        this.account = null;
        this.isConnected = false;
        this.updateUI();
        this.showNotification('Wallet disconnected', 'info');
    }

    async checkConnection() {
        try {
            const accounts = await this.web3.eth.getAccounts();
            if (accounts.length > 0) {
                this.account = accounts[0];
                this.networkId = await this.web3.eth.net.getId();
                this.isConnected = true;
                this.updateUI();
            }
        } catch (error) {
            console.error('Error checking connection:', error);
        }
    }

    updateUI() {
        const connectBtn = document.querySelector('.connect-btn');
        const accountDisplay = document.querySelector('.account-display');
        const networkDisplay = document.querySelector('.network-display');

        if (this.isConnected && this.account) {
            if (connectBtn) {
                connectBtn.textContent = this.formatAddress(this.account);
                connectBtn.classList.add('connected');
            }
            if (accountDisplay) {
                accountDisplay.textContent = this.formatAddress(this.account);
            }
            if (networkDisplay) {
                networkDisplay.textContent = this.getNetworkName(this.networkId);
            }
        } else {
            if (connectBtn) {
                connectBtn.textContent = 'Connect Wallet';
                connectBtn.classList.remove('connected');
            }
            if (accountDisplay) {
                accountDisplay.textContent = 'Not connected';
            }
            if (networkDisplay) {
                networkDisplay.textContent = 'No network';
            }
        }
    }

    formatAddress(address) {
        return address.substring(0, 6) + '...' + address.substring(address.length - 4);
    }

    getNetworkName(networkId) {
        const networks = {
            1: 'Ethereum Mainnet',
            5: 'Goerli Testnet',
            11155111: 'Sepolia Testnet',
            137: 'Polygon Mainnet',
            80001: 'Polygon Mumbai',
            56: 'BSC Mainnet',
            97: 'BSC Testnet',
            42161: 'Arbitrum One',
            421613: 'Arbitrum Goerli',
            10: 'Optimism',
            420: 'Optimism Goerli',
            43114: 'Avalanche C-Chain',
            43113: 'Avalanche Fuji',
            250: 'Fantom Opera',
            4002: 'Fantom Testnet'
        };
        return networks[networkId] || `Network ${networkId}`;
    }

    showNotification(message, type = 'info') {
        // Create notification element
        const notification = document.createElement('div');
        notification.className = `alert alert-${type} notification`;
        notification.style.cssText = `
            position: fixed;
            top: 20px;
            right: 20px;
            z-index: 1000;
            max-width: 300px;
            animation: slideIn 0.3s ease-out;
        `;
        notification.innerHTML = `
            ${message}
            <button type="button" class="btn-close" onclick="this.parentElement.remove()"></button>
        `;

        document.body.appendChild(notification);

        // Auto remove after 5 seconds
        setTimeout(() => {
            if (notification.parentElement) {
                notification.style.animation = 'slideOut 0.3s ease-out';
                setTimeout(() => notification.remove(), 300);
            }
        }, 5000);
    }

    // Token creation functionality
    async createToken(tokenData) {
        if (!this.isConnected) {
            this.showNotification('Please connect your wallet first', 'warning');
            return;
        }

        try {
            // This would interact with the Aetherweb3TokenCreator contract
            this.showNotification('Token creation feature coming soon!', 'info');
        } catch (error) {
            console.error('Error creating token:', error);
            this.showNotification('Error creating token: ' + error.message, 'error');
        }
    }

    // Get token balance
    async getTokenBalance(tokenAddress, account = this.account) {
        if (!this.isConnected || !account) return '0';

        try {
            const contract = new this.web3.eth.Contract([
                {
                    "constant": true,
                    "inputs": [{"name": "_owner", "type": "address"}],
                    "name": "balanceOf",
                    "outputs": [{"name": "balance", "type": "uint256"}],
                    "type": "function"
                },
                {
                    "constant": true,
                    "inputs": [],
                    "name": "decimals",
                    "outputs": [{"name": "", "type": "uint8"}],
                    "type": "function"
                }
            ], tokenAddress);

            const balance = await contract.methods.balanceOf(account).call();
            const decimals = await contract.methods.decimals().call();

            return (balance / Math.pow(10, decimals)).toFixed(4);
        } catch (error) {
            console.error('Error getting token balance:', error);
            return '0';
        }
    }
}

// Initialize the DApp when DOM is loaded
document.addEventListener('DOMContentLoaded', function() {
    window.aetherweb3DApp = new Aetherweb3DApp();

    // Add click handler for connect button
    const connectBtn = document.querySelector('.connect-btn');
    if (connectBtn) {
        connectBtn.addEventListener('click', () => {
            if (window.aetherweb3DApp.isConnected) {
                // Disconnect functionality could be added here
            } else {
                window.aetherweb3DApp.connectWallet();
            }
        });
    }
});

// Add CSS animations
const style = document.createElement('style');
style.textContent = `
    @keyframes slideIn {
        from { transform: translateX(100%); opacity: 0; }
        to { transform: translateX(0); opacity: 1; }
    }

    @keyframes slideOut {
        from { transform: translateX(0); opacity: 1; }
        to { transform: translateX(100%); opacity: 0; }
    }

    .notification {
        border-radius: 8px;
        box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
    }

    .connect-btn.connected {
        background: linear-gradient(135deg, #10b981 0%, #059669 100%);
    }

    .connect-btn.connected:hover {
        background: linear-gradient(135deg, #059669 0%, #047857 100%);
    }
`;
document.head.appendChild(style);
