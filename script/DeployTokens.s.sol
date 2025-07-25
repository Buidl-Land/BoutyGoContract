// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/BountyToken.sol";
import "../src/MockUSDC.sol";

/**
 * @title DeployTokens
 * @dev Deployment script for BountyToken and MockUSDC contracts
 */
contract DeployTokens is Script {
    function run() external {
        // Get deployment parameters from environment variables
        uint256 bountyTokenInitialSupply = vm.envOr("BOUNTY_TOKEN_INITIAL_SUPPLY", uint256(100_000_000 * 10**18)); // 100M tokens
        uint256 usdcInitialSupply = vm.envOr("USDC_INITIAL_SUPPLY", uint256(1_000_000 * 10**6)); // 1M USDC
        
        // Start broadcasting transactions
        vm.startBroadcast();
        
        // Deploy BountyToken
        BountyToken bountyToken = new BountyToken(
            "BountyGo Token",
            "BOUNTY",
            18, // 18 decimals for BOUNTY token
            bountyTokenInitialSupply
        );
        
        // Deploy MockUSDC
        MockUSDC mockUSDC = new MockUSDC(usdcInitialSupply);
        
        // Stop broadcasting
        vm.stopBroadcast();
        
        // Log deployment information
        console.log("=== Token Deployment Results ===");
        console.log("");
        
        console.log("BountyToken deployed at:", address(bountyToken));
        console.log("- Name:", bountyToken.name());
        console.log("- Symbol:", bountyToken.symbol());
        console.log("- Decimals:", bountyToken.decimals());
        console.log("- Initial Supply:", bountyToken.totalSupply() / 10**18, "BOUNTY");
        console.log("- Max Supply:", bountyToken.MAX_SUPPLY() / 10**18, "BOUNTY");
        console.log("- Owner:", bountyToken.owner());
        
        console.log("");
        
        console.log("MockUSDC deployed at:", address(mockUSDC));
        console.log("- Name:", mockUSDC.name());
        console.log("- Symbol:", mockUSDC.symbol());
        console.log("- Decimals:", mockUSDC.decimals());
        console.log("- Initial Supply:", mockUSDC.totalSupply() / 10**6, "USDC");
        console.log("- Max Supply:", mockUSDC.MAX_SUPPLY() / 10**6, "USDC");
        console.log("- Owner:", mockUSDC.owner());
        
        console.log("");
        console.log("=== Environment Variables for Main Contracts ===");
        console.log("USDC_ADDRESS=%s", address(mockUSDC));
        console.log("BOUNTY_TOKEN_ADDRESS=%s", address(bountyToken));
        
        console.log("");
        console.log("=== Next Steps ===");
        console.log("1. Set the above environment variables");
        console.log("2. Deploy PromotionPayment with: forge script script/DeployPromotionPayment.s.sol --broadcast");
        console.log("3. Deploy BountyEscrow with: forge script script/DeployBountyEscrow.s.sol --broadcast");
    }
}