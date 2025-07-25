// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/BountyToken.sol";
import "../src/MockUSDC.sol";
import "../src/PromotionPayment.sol";
import "../src/BountyEscrow.sol";

/**
 * @title DeployAll
 * @dev Comprehensive deployment script for all BountyGo contracts on Injective testnet
 * @notice This script deploys tokens first, then the main contracts
 */
contract DeployAll is Script {
    // Deployment configuration
    struct DeploymentConfig {
        address treasury;
        uint256 bountyTokenInitialSupply;
        uint256 usdcInitialSupply;
        uint256 platformFeePercent;
        uint256 disputeWindow;
        address[] additionalResolvers;
    }
    
    // Deployed contract addresses
    struct DeployedContracts {
        address bountyToken;
        address mockUSDC;
        address promotionPayment;
        address bountyEscrow;
    }
    
    function run() external returns (DeployedContracts memory) {
        // Load configuration from environment variables
        DeploymentConfig memory config = loadConfig();
        
        console.log("=== BountyGo Contracts Deployment on Injective Testnet ===");
        console.log("Chain ID: 1439");
        console.log("RPC: https://k8s.testnet.json-rpc.injective.network/");
        console.log("");
        
        // Validate configuration
        validateConfig(config);
        
        // Start broadcasting transactions
        vm.startBroadcast();
        
        // Deploy tokens first
        console.log("Step 1: Deploying tokens...");
        BountyToken bountyToken = deployBountyToken(config);
        MockUSDC mockUSDC = deployMockUSDC(config);
        
        // Deploy main contracts
        console.log("Step 2: Deploying main contracts...");
        PromotionPayment promotionPayment = deployPromotionPayment(
            config, 
            address(mockUSDC), 
            address(bountyToken)
        );
        
        BountyEscrow bountyEscrow = deployBountyEscrow(
            config, 
            address(mockUSDC), 
            address(bountyToken)
        );
        
        // Configure additional dispute resolvers
        configureDisputeResolvers(bountyEscrow, config);
        
        // Stop broadcasting
        vm.stopBroadcast();
        
        // Create deployment summary
        DeployedContracts memory deployed = DeployedContracts({
            bountyToken: address(bountyToken),
            mockUSDC: address(mockUSDC),
            promotionPayment: address(promotionPayment),
            bountyEscrow: address(bountyEscrow)
        });
        
        // Log deployment results
        logDeploymentResults(deployed, config);
        
        // Save deployment addresses to file
        saveDeploymentAddresses(deployed);
        
        return deployed;
    }
    
    function loadConfig() internal view returns (DeploymentConfig memory) {
        // Load treasury address (required)
        address treasury = vm.envAddress("TREASURY_ADDRESS");
        
        // Load token supplies with defaults
        uint256 bountyTokenInitialSupply = vm.envOr(
            "BOUNTY_TOKEN_INITIAL_SUPPLY", 
            uint256(100_000_000 * 10**18)
        ); // 100M BOUNTY tokens
        
        uint256 usdcInitialSupply = vm.envOr(
            "USDC_INITIAL_SUPPLY", 
            uint256(1_000_000 * 10**6)
        ); // 1M USDC
        
        // Load escrow configuration with defaults
        uint256 platformFeePercent = vm.envOr("PLATFORM_FEE_PERCENT", uint256(250)); // 2.5%
        uint256 disputeWindow = vm.envOr("DISPUTE_WINDOW", uint256(7 days)); // 7 days
        
        // Load additional dispute resolvers
        address[] memory additionalResolvers = vm.envOr("DISPUTE_RESOLVERS", ",", new address[](0));
        
        return DeploymentConfig({
            treasury: treasury,
            bountyTokenInitialSupply: bountyTokenInitialSupply,
            usdcInitialSupply: usdcInitialSupply,
            platformFeePercent: platformFeePercent,
            disputeWindow: disputeWindow,
            additionalResolvers: additionalResolvers
        });
    }
    
    function validateConfig(DeploymentConfig memory config) internal pure {
        require(config.treasury != address(0), "TREASURY_ADDRESS not set");
        require(config.platformFeePercent <= 1000, "Platform fee too high (max 10%)");
        require(config.bountyTokenInitialSupply > 0, "Bounty token initial supply must be > 0");
        require(config.usdcInitialSupply > 0, "USDC initial supply must be > 0");
    }
    
    function deployBountyToken(DeploymentConfig memory config) internal returns (BountyToken) {
        console.log("  Deploying BountyToken...");
        
        BountyToken bountyToken = new BountyToken(
            "BountyGo Token",
            "BOUNTY",
            18, // 18 decimals
            config.bountyTokenInitialSupply
        );
        
        console.log("  [OK] BountyToken deployed at:", address(bountyToken));
        return bountyToken;
    }
    
    function deployMockUSDC(DeploymentConfig memory config) internal returns (MockUSDC) {
        console.log("  Deploying MockUSDC...");
        
        MockUSDC mockUSDC = new MockUSDC(config.usdcInitialSupply);
        
        console.log("  [OK] MockUSDC deployed at:", address(mockUSDC));
        return mockUSDC;
    }
    
    function deployPromotionPayment(
        DeploymentConfig memory config,
        address usdcAddress,
        address bountyTokenAddress
    ) internal returns (PromotionPayment) {
        console.log("  Deploying PromotionPayment...");
        
        PromotionPayment promotionPayment = new PromotionPayment(
            config.treasury,
            usdcAddress,
            bountyTokenAddress
        );
        
        console.log("  [OK] PromotionPayment deployed at:", address(promotionPayment));
        return promotionPayment;
    }
    
    function deployBountyEscrow(
        DeploymentConfig memory config,
        address usdcAddress,
        address bountyTokenAddress
    ) internal returns (BountyEscrow) {
        console.log("  Deploying BountyEscrow...");
        
        BountyEscrow bountyEscrow = new BountyEscrow(
            config.treasury,
            usdcAddress,
            bountyTokenAddress,
            config.platformFeePercent,
            config.disputeWindow
        );
        
        console.log("  [OK] BountyEscrow deployed at:", address(bountyEscrow));
        return bountyEscrow;
    }
    
    function configureDisputeResolvers(
        BountyEscrow bountyEscrow,
        DeploymentConfig memory config
    ) internal {
        if (config.additionalResolvers.length > 0) {
            console.log("  Configuring additional dispute resolvers...");
            
            for (uint256 i = 0; i < config.additionalResolvers.length; i++) {
                if (config.additionalResolvers[i] != address(0)) {
                    bountyEscrow.addDisputeResolver(config.additionalResolvers[i]);
                    console.log("  [OK] Added dispute resolver:", config.additionalResolvers[i]);
                }
            }
        }
    }
    
    function logDeploymentResults(
        DeployedContracts memory deployed,
        DeploymentConfig memory config
    ) internal view {
        console.log("");
        console.log("=== DEPLOYMENT SUCCESSFUL ===");
        console.log("");
        
        // Contract addresses
        console.log("[CONTRACTS] Contract Addresses:");
        console.log("BountyToken:      %s", deployed.bountyToken);
        console.log("MockUSDC:         %s", deployed.mockUSDC);
        console.log("PromotionPayment: %s", deployed.promotionPayment);
        console.log("BountyEscrow:     %s", deployed.bountyEscrow);
        console.log("");
        
        // Configuration summary
        console.log("[CONFIG] Configuration:");
        console.log("Treasury:         %s", config.treasury);
        console.log("Platform Fee:     %d.%d%%", config.platformFeePercent / 100, config.platformFeePercent % 100);
        console.log("Dispute Window:   %d days", config.disputeWindow / 86400);
        console.log("Network:          Injective Testnet (Chain ID: 1439)");
        console.log("");
        
        // Token information
        console.log("[TOKENS] Token Information:");
        console.log("BOUNTY Token:     18 decimals, %d initial supply", config.bountyTokenInitialSupply / 10**18);
        console.log("Mock USDC:        6 decimals, %d initial supply", config.usdcInitialSupply / 10**6);
        console.log("");
        
        // Next steps
        console.log("[NEXT] Next Steps:");
        console.log("1. Verify contracts on Injective Explorer");
        console.log("2. Update frontend configuration with contract addresses");
        console.log("3. Test contract interactions on testnet");
        console.log("4. Set up monitoring and alerts");
        console.log("");
        
        // Environment variables for frontend
        console.log("[ENV] Environment Variables for Frontend:");
        console.log("BOUNTY_TOKEN_ADDRESS=%s", deployed.bountyToken);
        console.log("USDC_ADDRESS=%s", deployed.mockUSDC);
        console.log("PROMOTION_PAYMENT_ADDRESS=%s", deployed.promotionPayment);
        console.log("BOUNTY_ESCROW_ADDRESS=%s", deployed.bountyEscrow);
        console.log("TREASURY_ADDRESS=%s", config.treasury);
    }
    
    function saveDeploymentAddresses(DeployedContracts memory deployed) internal {
        // Create deployment info JSON string
        string memory deploymentInfo = string(abi.encodePacked(
            "{\n",
            '  "network": "injective-testnet",\n',
            '  "chainId": 1439,\n',
            '  "timestamp": ', vm.toString(block.timestamp), ',\n',
            '  "contracts": {\n',
            '    "BountyToken": "', vm.toString(deployed.bountyToken), '",\n',
            '    "MockUSDC": "', vm.toString(deployed.mockUSDC), '",\n',
            '    "PromotionPayment": "', vm.toString(deployed.promotionPayment), '",\n',
            '    "BountyEscrow": "', vm.toString(deployed.bountyEscrow), '"\n',
            '  }\n',
            "}"
        ));
        
        // Write to file (this will be saved in the broadcast directory)
        vm.writeFile("./deployments/injective-testnet.json", deploymentInfo);
        console.log("Deployment addresses saved to: ./deployments/injective-testnet.json");
    }
}