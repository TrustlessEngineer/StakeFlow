// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/StakeFlowStaking.sol";
import "../contracts/StakeFlowToken.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title DeployScript
 * @notice Deployment script for StakeFlow protocol
 * @dev Run with: forge script scripts/Deploy.s.sol --rpc-url <RPC_URL> --broadcast
 */
contract DeployScript is Script {
    
    struct DeploymentConfig {
        address owner;
        address feeRecipient;
        string tokenName;
        string tokenSymbol;
    }
    
    function run() external {
        // Load configuration from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        DeploymentConfig memory config = DeploymentConfig({
            owner: vm.envAddress("OWNER_ADDRESS"),
            feeRecipient: vm.envAddress("FEE_RECIPIENT"),
            tokenName: vm.envOr("TOKEN_NAME", string("StakeFlow Token")),
            tokenSymbol: vm.envOr("TOKEN_SYMBOL", string("SFT"))
        });
        
        console.log("=== StakeFlow Deployment ===");
        console.log("Deployer:", vm.addr(deployerPrivateKey));
        console.log("Owner:", config.owner);
        console.log("Fee Recipient:", config.feeRecipient);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. Deploy Reward Token
        StakeFlowToken rewardToken = new StakeFlowToken(
            config.tokenName,
            config.tokenSymbol,
            config.owner
        );
        console.log("Reward Token deployed at:", address(rewardToken));
        
        // 2. Deploy Staking Contract
        StakeFlowStaking staking = new StakeFlowStaking(
            config.owner,
            config.feeRecipient
        );
        console.log("Staking Contract deployed at:", address(staking));
        
        // 3. Setup permissions
        rewardToken.setMinter(address(staking), true);
        console.log("Staking contract set as minter");
        
        vm.stopBroadcast();
        
        // Log deployment summary
        console.log("\n=== Deployment Summary ===");
        console.log("Network:", block.chainid);
        console.log("Reward Token:", address(rewardToken));
        console.log("Staking Contract:", address(staking));
        
        // Write deployment addresses to file
        string memory deploymentJson = string.concat(
            '{\n',
            '  "network": ', vm.toString(block.chainid), ',\n',
            '  "rewardToken": "', vm.toString(address(rewardToken)), '",\n',
            '  "stakingContract": "', vm.toString(address(staking)), '",\n',
            '  "owner": "', vm.toString(config.owner), '",\n',
            '  "feeRecipient": "', vm.toString(config.feeRecipient), '",\n',
            '  "timestamp": ', vm.toString(block.timestamp), '\n',
            '}'
        );
        
        vm.writeFile(
            string.concat("./deployments/", vm.toString(block.chainid), ".json"),
            deploymentJson
        );
    }
}

/**
 * @title DeployAndSetupScript
 * @notice Extended deployment with initial pool setup
 */
contract DeployAndSetupScript is Script {
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address owner = vm.envAddress("OWNER_ADDRESS");
        address feeRecipient = vm.envAddress("FEE_RECIPIENT");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy contracts
        StakeFlowToken rewardToken = new StakeFlowToken("StakeFlow Token", "SFT", owner);
        StakeFlowStaking staking = new StakeFlowStaking(owner, feeRecipient);
        rewardToken.setMinter(address(staking), true);
        
        // Create initial pool (if staking token address provided)
        address stakingToken = vm.envOr("STAKING_TOKEN", address(0));
        if (stakingToken != address(0)) {
            uint256 poolId = staking.createPool(
                stakingToken,
                address(rewardToken),
                1e12,        // 1 token/sec reward rate
                7 days,      // 7 day lock
                100,         // 1% deposit fee
                100          // 1% withdraw fee
            );
            console.log("Initial pool created with ID:", poolId);
            
            // Add initial rewards if amount specified
            uint256 initialRewards = vm.envOr("INITIAL_REWARDS", uint256(0));
            if (initialRewards > 0) {
                rewardToken.approve(address(staking), initialRewards);
                staking.addRewards(poolId, initialRewards, 90 days);
                console.log("Initial rewards added:", initialRewards);
            }
        }
        
        vm.stopBroadcast();
        
        console.log("=== Deployment Complete ===");
        console.log("Reward Token:", address(rewardToken));
        console.log("Staking:", address(staking));
    }
}
