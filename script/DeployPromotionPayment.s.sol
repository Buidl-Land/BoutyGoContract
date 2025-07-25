// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/PromotionPayment.sol";

/**
 * @title DeployPromotionPayment
 * @dev Deployment script for PromotionPayment contract
 */
contract DeployPromotionPayment is Script {
    function run() external {
        // Get deployment parameters from environment variables
        address treasury = vm.envAddress("TREASURY_ADDRESS");
        address usdcAddress = vm.envAddress("USDC_ADDRESS");
        address bountyTokenAddress = vm.envAddress("BOUNTY_TOKEN_ADDRESS");
        
        // Validate addresses
        require(treasury != address(0), "TREASURY_ADDRESS not set");
        require(usdcAddress != address(0), "USDC_ADDRESS not set");
        require(bountyTokenAddress != address(0), "BOUNTY_TOKEN_ADDRESS not set");
        
        // Start broadcasting transactions
        vm.startBroadcast();
        
        // Deploy PromotionPayment contract
        PromotionPayment promotionPayment = new PromotionPayment(
            treasury,
            usdcAddress,
            bountyTokenAddress
        );
        
        // Stop broadcasting
        vm.stopBroadcast();
        
        // Log deployment information
        console.log("=== PromotionPayment Deployment Results ===");
        console.log("");
        console.log("PromotionPayment deployed at:", address(promotionPayment));
        console.log("Treasury address:", treasury);
        console.log("Contract owner:", promotionPayment.owner());
        
        // Log supported tokens
        console.log("");
        console.log("Supported tokens:");
        (address usdc, address bounty) = promotionPayment.getSupportedTokens();
        console.log("- USDC:", usdc);
        console.log("- Bounty Token:", bounty);
        
        // Log service prices
        console.log("");
        console.log("Service Prices:");
        PromotionPayment.ServicePrice memory taskTopPrice = promotionPayment.getServicePrice(
            PromotionPayment.ServiceType.TASK_TOP
        );
        console.log("- Task Top: %d USDC per day", taskTopPrice.pricePerDay / 10**6);
        
        PromotionPayment.ServicePrice memory precisionPushPrice = promotionPayment.getServicePrice(
            PromotionPayment.ServiceType.PRECISION_PUSH
        );
        console.log("- Precision Push: %d USDC per user", precisionPushPrice.pricePerUser / 10**4); // 0.1 USDC = 100000 units
        
        PromotionPayment.ServicePrice memory bannerPrice = promotionPayment.getServicePrice(
            PromotionPayment.ServiceType.BANNER_DISPLAY
        );
        console.log("- Banner Display: %d USDC per day", bannerPrice.pricePerDay / 10**6);
        
        PromotionPayment.ServicePrice memory tagPriorityPrice = promotionPayment.getServicePrice(
            PromotionPayment.ServiceType.TAG_PRIORITY
        );
        console.log("- Tag Priority: %d USDC per day", tagPriorityPrice.pricePerDay / 10**6);
        
        console.log("");
        console.log("=== Contract Configuration ===");
        console.log("- Only ERC20 tokens supported (USDC and Bounty Token)");
        console.log("- ETH payments removed for security and simplicity");
        console.log("- All service prices are denominated in USDC (6 decimals)");
        
        console.log("");
        console.log("=== Usage Instructions ===");
        console.log("1. Users must approve the contract to spend their tokens before payment");
        console.log("2. Use payForPromotion() function with token address and amount");
        console.log("3. Owner can activate services using activateService()");
        console.log("4. Owner can complete services using completeService()");
    }
}