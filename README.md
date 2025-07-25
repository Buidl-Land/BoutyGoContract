# BountyGo Smart Contracts

This directory contains the smart contracts for the BountyGo platform, implementing cryptocurrency payment processing for promotion services and bounty escrow functionality.

## Overview

The BountyGo smart contracts consist of two main components:

1. **PromotionPayment.sol** - Handles cryptocurrency payments for promotion services
2. **BountyEscrow.sol** - Manages escrow functionality for bounty rewards with dispute resolution

## Features

### PromotionPayment Contract
- Support for multiple cryptocurrencies (ETH, USDC, MATIC)
- Four promotion service types:
  - Task Top Recommendation (10 USDC/day)
  - Precision User Push (0.1 USDC/user)
  - Homepage Banner Display (50 USDC/day)
  - Tag Page Priority Display (20 USDC/day)
- Configurable pricing and supported tokens
- Owner-controlled service activation
- Emergency withdrawal functionality

### BountyEscrow Contract
- Secure escrow for bounty rewards
- Multi-token support (ETH, USDC, MATIC)
- Configurable platform fees
- Dispute resolution system
- Automatic refunds for expired tasks
- Time-locked dispute windows

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) installed
- Node.js and npm (for additional tooling)
- Access to Injective testnet with funded wallet

## Installation

1. Clone the repository and navigate to the contracts directory:
```bash
cd contracts
```

2. Install dependencies:
```bash
forge install
```

3. Copy the environment template:
```bash
cp .env.example .env
```

4. Fill in your environment variables in `.env`:
```bash
# Required
PRIVATE_KEY=your_private_key_without_0x_prefix
TREASURY_ADDRESS=0x1234567890123456789012345678901234567890

# Optional token addresses
USDC_ADDRESS=0x...
MATIC_ADDRESS=0x...

# BountyEscrow configuration
PLATFORM_FEE_PERCENT=250  # 2.5%
DISPUTE_WINDOW=604800      # 7 days
```

## Compilation

Compile the contracts:
```bash
forge build
```

## Testing

Run the test suite:
```bash
forge test
```

Run tests with gas reporting:
```bash
forge test --gas-report
```

## Deployment

### Deploy to Injective Testnet

1. **Deploy PromotionPayment Contract:**
```bash
forge script script/DeployPromotionPayment.s.sol --rpc-url injective_testnet --broadcast --verify
```

2. **Deploy BountyEscrow Contract:**
```bash
forge script script/DeployBountyEscrow.s.sol --rpc-url injective_testnet --broadcast --verify
```

### Deploy Both Contracts
```bash
# Deploy PromotionPayment
forge script script/DeployPromotionPayment.s.sol --rpc-url injective_testnet --broadcast

# Deploy BountyEscrow
forge script script/DeployBountyEscrow.s.sol --rpc-url injective_testnet --broadcast
```

## Network Configuration

The contracts are configured for Injective testnet:
- **Chain ID:** 1439
- **RPC URL:** https://k8s.testnet.json-rpc.injective.network/
- **Explorer:** https://testnet.explorer.injective.network/

## Contract Addresses

After deployment, update this section with the deployed contract addresses:

```
PromotionPayment: 0x... (to be filled after deployment)
BountyEscrow: 0x... (to be filled after deployment)
```

## Usage Examples

### PromotionPayment Contract

```solidity
// Pay for task top promotion with USDC
promotionPayment.payForPromotion(
    PromotionPayment.ServiceType.TASK_TOP,
    3, // 3 days
    usdcAddress,
    30 * 10**6 // 30 USDC
);

// Pay for banner display with ETH
promotionPayment.payForPromotionETH{value: 0.1 ether}(
    PromotionPayment.ServiceType.BANNER_DISPLAY,
    1 // 1 day
);
```

### BountyEscrow Contract

```solidity
// Deposit reward for a task
bountyEscrow.depositReward(
    taskId,
    usdcAddress,
    500 * 10**6, // 500 USDC
    block.timestamp + 30 days // 30 day deadline
);

// Release reward to winner
bountyEscrow.releaseReward(taskId, winnerAddress);

// Create dispute
bountyEscrow.createDispute(taskId, "Winner did not complete the task properly");
```

## Security Considerations

1. **Private Key Security:** Never commit your private key to version control
2. **Treasury Address:** Ensure the treasury address is correct and secure
3. **Token Addresses:** Verify token contract addresses before adding support
4. **Platform Fees:** Set reasonable platform fees to avoid user dissatisfaction
5. **Dispute Resolution:** Ensure dispute resolvers are trustworthy addresses

## Architecture

```
contracts/
├── src/
│   ├── PromotionPayment.sol    # Promotion payment contract
│   └── BountyEscrow.sol        # Bounty escrow contract
├── script/
│   ├── DeployPromotionPayment.s.sol  # Deployment script for PromotionPayment
│   └── DeployBountyEscrow.s.sol      # Deployment script for BountyEscrow
├── test/
│   └── (test files)
├── lib/
│   ├── forge-std/              # Foundry standard library
│   └── openzeppelin-contracts/ # OpenZeppelin contracts
├── foundry.toml                # Foundry configuration
├── .env.example               # Environment template
└── README.md                  # This file
```

## Gas Optimization

The contracts are optimized for gas efficiency:
- Use of `uint256` for gas-efficient operations
- Packed structs where possible
- Efficient storage patterns
- Minimal external calls

## Upgradeability

The current contracts are not upgradeable by design for security and trust reasons. If upgrades are needed:
1. Deploy new contract versions
2. Migrate data if necessary
3. Update frontend integrations

## Support

For technical support or questions:
1. Check the contract documentation
2. Review the test files for usage examples
3. Consult the Foundry documentation
4. Contact the development team

## License

This project is licensed under the MIT License - see the contract files for details.
