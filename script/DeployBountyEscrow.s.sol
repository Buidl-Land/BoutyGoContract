// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/BountyEscrow.sol";

/**
 * @title DeployBountyEscrow
 * @dev Deployment script for BountyEscrow contract
 */
contract DeployBountyEscrow is Script {
    function run() external {
        // Get deployment parameters from environment variables
        address treasury = vm.envAddress("TREASURY_ADDRESS");
        address usdcAddress = vm.envAddress("USDC_ADDRESS");
        address bountyTokenAddress = vm.envAddress("BOUNTY_TOKEN_ADDRESS");
        uint256 platformFeePercent = vm.envOr("PLATFORM_FEE_PERCENT", uint256(250)); // Default 2.5%
        uint256 disputeWindow = vm.envOr("DISPUTE_WINDOW", uint256(7 days)); // Default 7 days
        
        // Validate addresses
        require(treasury != address(0), "TREASURY_ADDRESS not set");
        require(usdcAddress != address(0), "USDC_ADDRESS not set");
        require(bountyTokenAddress != address(0), "BOUNTY_TOKEN_ADDRESS not set");
        
        // Start broadcasting transactions
        vm.startBroadcast();
        
        // Deploy BountyEscrow contract
        BountyEscrow bountyEscrow = new BountyEscrow(
            treasury,
            usdcAddress,
            bountyTokenAddress,
            platformFeePercent,
            disputeWindow
        );
        
        // Add additional dispute resolvers if provided
        address[] memory additionalResolvers = vm.envOr("DISPUTE_RESOLVERS", ",", new address[](0));
        for (uint256 i = 0; i < additionalResolvers.length; i++) {
            if (additionalResolvers[i] != address(0)) {
                bountyEscrow.addDisputeResolver(additionalResolvers[i]);
            }
        }
        
        // Stop broadcasting
        vm.stopBroadcast();
        
        // Log deployment information
        console.log("=== BountyEscrow Deployment Results ===");
        console.log("");
        console.log("BountyEscrow deployed at:", address(bountyEscrow));
        console.log("Treasury address:", treasury);
        console.log("Platform fee percent:", platformFeePercent, "basis points");
        console.log("Dispute window:", disputeWindow, "seconds");
        console.log("Contract owner:", bountyEscrow.owner());
        
        // Log supported tokens
        console.log("");
        console.log("Supported tokens:");
        (address usdc, address bounty) = bountyEscrow.getSupportedTokens();
        console.log("- USDC:", usdc);
        console.log("- Bounty Token:", bounty);
        
        // Log dispute resolvers
        console.log("");
        console.log("Dispute resolvers:");
        console.log("- Owner (deployer): true");
        for (uint256 i = 0; i < additionalResolvers.length; i++) {
            if (additionalResolvers[i] != address(0)) {
                console.log("- Additional resolver:", additionalResolvers[i]);
            }
        }
        
        // Log configuration details
        console.log("");
        console.log("=== Contract Configuration ===");
        console.log("- Platform fee: %d.%d%%", platformFeePercent / 100, platformFeePercent % 100);
        console.log("- Dispute window: %d days", disputeWindow / 86400);
        console.log("- Only ERC20 tokens supported (USDC and Bounty Token)");
        console.log("- ETH payments removed for security and simplicity");
        
        console.log("");
        console.log("=== Usage Instructions ===");
        console.log("1. Sponsors deposit rewards using depositReward() with token address and amount");
        console.log("2. Users must approve the contract to spend their tokens before deposit");
        console.log("3. Sponsors or owner can release rewards using releaseReward()");
        console.log("4. Expired tasks can be refunded using refundExpired()");
        console.log("5. Disputes can be created and resolved by authorized resolvers");
        
        console.log("");
        console.log("=== Security Features ===");
        console.log("- Reentrancy protection on all state-changing functions");
        console.log("- Pausable contract for emergency situations");
        console.log("- Multi-signature dispute resolution system");
        console.log("- Platform fee collection for sustainability");
    }
}