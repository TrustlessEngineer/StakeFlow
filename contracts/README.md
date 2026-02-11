# StakeFlow Smart Contracts

## Overview

This directory contains the core smart contracts for the StakeFlow DeFi staking protocol.

## Contracts

### StakeFlowStaking.sol
Main staking contract handling all staking logic, reward distribution, and pool management.

### StakeFlowToken.sol
ERC20 reward token with minting capabilities for stakers and governance features.

### IStakeFlowStaking.sol
Interface defining the contract's external API and events.

## Development

```bash
# Install dependencies
forge install

# Compile
forge build

# Test
forge test

# Gas snapshot
forge snapshot
```

## Deployment

See `../scripts/Deploy.s.sol` for deployment scripts.
