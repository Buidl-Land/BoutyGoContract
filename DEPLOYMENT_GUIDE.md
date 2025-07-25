# BountyGo Smart Contracts Deployment Guide

## Overview

This guide provides step-by-step instructions for deploying the BountyGo smart contracts to the Injective testnet. The deployment includes:

- **BountyToken**: ERC20 token for platform rewards
- **MockUSDC**: Test USDC token for payments
- **PromotionPayment**: Handles cryptocurrency payments for promotion services
- **BountyEscrow**: Manages bounty reward escrow with dispute resolution

## Prerequisites

### 1. Development Environment

```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Verify installation
forge --version
cast --version
```

### 2. Injective Testnet Setup

- **Chain ID**: 1439
- **RPC URL**: https://k8s.testnet.json-rpc.injective.network/
- **Explorer**: https://testnet.explorer.injective.network/
- **Faucet**: https://testnet.faucet.injective.network/

### 3. Wallet Preparation

1. Create a dedicated deployment wallet
2. Get testnet INJ tokens from the faucet
3. Export your private key (keep it secure!)

## Quick Start Deployment

### Step 1: Environment Configuration

```bash
# Copy environment template
cp .env.example .env

# Edit .env file with your values
nano .env
```

**Required Environment Variables:**
```bash
# Your deployment wallet private key (without 0x prefix)
PRIVATE_KEY=your_private_key_here

# Treasury address to receive platform fees
TREASURY_ADDRESS=0x1234567890123456789012345678901234567890

# Optional: Customize token supplies
BOUNTY_TOKEN_INITIAL_SUPPLY=100000000000000000000000000  # 100M tokens
USDC_INITIAL_SUPPLY=1000000000000                        # 1M USDC

# Optional: Customize escrow settings
PLATFORM_FEE_PERCENT=250    # 2.5% platform fee
DISPUTE_WINDOW=604800       # 7 days dispute window
```

### Step 2: Deploy All Contracts

```bash
# Deploy all contracts in one command
forge script script/DeployAll.s.sol --rpc-url injective_testnet --broadcast --verify -vvvv
```

### Step 3: Verify Deployment

After successful deployment, you'll see output like:
```
[CONTRACTS] Contract Addresses:
BountyToken:      0x1234...
MockUSDC:         0x5678...
PromotionPayment: 0x9abc...
BountyEscrow:     0xdef0...
```

## Alternative Deployment Methods

### Method 1: Step-by-Step Deployment

```bash
# 1. Deploy tokens first
forge script script/DeployTokens.s.sol --rpc-url injective_testnet --broadcast -vvvv

# 2. Update .env with token addresses from step 1
# USDC_ADDRESS=0x...
# BOUNTY_TOKEN_ADDRESS=0x...

# 3. Deploy PromotionPayment
forge script script/DeployPromotionPayment.s.sol --rpc-url injective_testnet --broadcast -vvvv

# 4. Deploy BountyEscrow
forge script script/DeployBountyEscrow.s.sol --rpc-url injective_testnet --broadcast -vvvv
```

### Method 2: Individual Contract Deployment

```bash
# Deploy only specific contracts
forge script script/DeployPromotionPayment.s.sol --rpc-url injective_testnet --broadcast
forge script script/DeployBountyEscrow.s.sol --rpc-url injective_testnet --broadcast
```

## Contract Configuration

### PromotionPayment Default Prices

| Service Type | Price | Unit |
|--------------|-------|------|
| Task Top | 10 USDC | per day |
| Precision Push | 0.1 USDC | per user |
| Banner Display | 50 USDC | per day |
| Tag Priority | 20 USDC | per day |

### BountyEscrow Default Settings

- **Platform Fee**: 2.5% (250 basis points)
- **Dispute Window**: 7 days (604800 seconds)
- **Supported Tokens**: USDC and BOUNTY token only
- **Security Features**: Reentrancy protection, pausable, dispute resolution

## Post-Deployment Tasks

### 1. Contract Verification

If verification failed during deployment:
```bash
forge verify-contract <CONTRACT_ADDRESS> <CONTRACT_NAME> --chain-id 1439 --watch
```

### 2. Frontend Integration

Update your frontend configuration with the deployed addresses:
```javascript
// Frontend environment variables
BOUNTY_TOKEN_ADDRESS=0x...
USDC_ADDRESS=0x...
PROMOTION_PAYMENT_ADDRESS=0x...
BOUNTY_ESCROW_ADDRESS=0x...
TREASURY_ADDRESS=0x...
```

### 3. Testing Deployment

```bash
# Test contract interactions
cast call <BOUNTY_TOKEN_ADDRESS> "name()" --rpc-url injective_testnet
cast call <USDC_ADDRESS> "symbol()" --rpc-url injective_testnet
cast call <PROMOTION_PAYMENT_ADDRESS> "owner()" --rpc-url injective_testnet
```

### 4. Set Up Monitoring

- Monitor contract addresses on Injective Explorer
- Set up alerts for important transactions
- Monitor treasury balance and fee collection

## Troubleshooting

### Common Issues

**1. Insufficient Gas**
```bash
# Increase gas limit
forge script script/DeployAll.s.sol --rpc-url injective_testnet --broadcast --gas-limit 3000000
```

**2. RPC Connection Issues**
```bash
# Try alternative RPC endpoints or check network status
curl -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  https://k8s.testnet.json-rpc.injective.network/
```

**3. Private Key Issues**
- Ensure private key is without 0x prefix
- Verify wallet has sufficient INJ for gas fees
- Check wallet permissions and network settings

**4. Contract Verification Failures**
```bash
# Manual verification with source code
forge verify-contract <ADDRESS> <CONTRACT_NAME> \
  --chain-id 1439 \
  --constructor-args $(cast abi-encode "constructor(address,address,address)" <ARG1> <ARG2> <ARG3>)
```

### Getting Help

- **Injective Documentation**: https://docs.injective.network/
- **Foundry Documentation**: https://book.getfoundry.sh/
- **Contract Source Code**: Check the `src/` directory for implementation details

## Security Considerations

### Pre-Deployment Checklist

- [ ] Private keys stored securely
- [ ] Treasury address verified
- [ ] Contract parameters reviewed
- [ ] Test deployment on testnet first
- [ ] Code audit completed (for production)

### Post-Deployment Security

- [ ] Verify contract source code on explorer
- [ ] Test all contract functions
- [ ] Set up monitoring and alerts
- [ ] Document all contract addresses
- [ ] Backup deployment artifacts

### Production Deployment Notes

When deploying to mainnet:
1. Use hardware wallet for deployment
2. Perform comprehensive security audit
3. Test extensively on testnet first
4. Use multi-signature wallets for admin functions
5. Implement gradual rollout strategy
6. Set up comprehensive monitoring

## Contract Addresses

After deployment, record your contract addresses here:

```
Network: Injective Testnet (Chain ID: 1439)
Deployment Date: ___________

BountyToken:      0x________________________________
MockUSDC:         0x________________________________
PromotionPayment: 0x________________________________
BountyEscrow:     0x________________________________
Treasury:         0x________________________________

Deployer Address: 0x________________________________
```

## Support

For deployment support or questions:
1. Check the troubleshooting section above
2. Review contract documentation in `src/` directory
3. Consult Injective and Foundry documentation
4. Contact the development team

---

**⚠️ Important**: Always test thoroughly on testnet before any mainnet deployment. Keep your private keys secure and never commit them to version control.