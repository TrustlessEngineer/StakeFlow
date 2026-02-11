export const StakeFlowStakingABI = [
  {
    "inputs": [
      { "internalType": "address", "name": "_initialOwner", "type": "address" },
      { "internalType": "address", "name": "_feeRecipient", "type": "address" }
    ],
    "stateMutability": "nonpayable",
    "type": "constructor"
  },
  {
    "inputs": [
      { "internalType": "address", "name": "_stakingToken", "type": "address" },
      { "internalType": "address", "name": "_rewardToken", "type": "address" },
      { "internalType": "uint256", "name": "_rewardRate", "type": "uint256" },
      { "internalType": "uint256", "name": "_lockDuration", "type": "uint256" },
      { "internalType": "uint256", "name": "_depositFee", "type": "uint256" },
      { "internalType": "uint256", "name": "_withdrawFee", "type": "uint256" }
    ],
    "name": "createPool",
    "outputs": [{ "internalType": "uint256", "name": "poolId", "type": "uint256" }],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      { "internalType": "uint256", "name": "_poolId", "type": "uint256" },
      { "internalType": "uint256", "name": "_amount", "type": "uint256" }
    ],
    "name": "stake",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      { "internalType": "uint256", "name": "_poolId", "type": "uint256" },
      { "internalType": "uint256", "name": "_amount", "type": "uint256" }
    ],
    "name": "withdraw",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [{ "internalType": "uint256", "name": "_poolId", "type": "uint256" }],
    "name": "emergencyWithdraw",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [{ "internalType": "uint256", "name": "_poolId", "type": "uint256" }],
    "name": "claimRewards",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [{ "internalType": "uint256", "name": "_poolId", "type": "uint256" }],
    "name": "compound",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      { "internalType": "uint256", "name": "_poolId", "type": "uint256" },
      { "internalType": "uint256", "name": "_amount", "type": "uint256" },
      { "internalType": "uint256", "name": "_duration", "type": "uint256" }
    ],
    "name": "addRewards",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      { "internalType": "uint256", "name": "_poolId", "type": "uint256" },
      { "internalType": "address", "name": "_user", "type": "address" }
    ],
    "name": "pendingRewards",
    "outputs": [{ "internalType": "uint256", "name": "", "type": "uint256" }],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      { "internalType": "uint256", "name": "_poolId", "type": "uint256" },
      { "internalType": "address", "name": "_user", "type": "address" }
    ],
    "name": "getUserInfo",
    "outputs": [{
      "components": [
        { "internalType": "uint256", "name": "stakedAmount", "type": "uint256" },
        { "internalType": "uint256", "name": "rewardDebt", "type": "uint256" },
        { "internalType": "uint256", "name": "pendingRewards", "type": "uint256" },
        { "internalType": "uint256", "name": "lastStakeTime", "type": "uint256" },
        { "internalType": "uint256", "name": "unlockTime", "type": "uint256" }
      ],
      "internalType": "struct IStakeFlowStaking.UserInfo",
      "name": "",
      "type": "tuple"
    }],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [{ "internalType": "uint256", "name": "_poolId", "type": "uint256" }],
    "name": "getPool",
    "outputs": [{
      "components": [
        { "internalType": "address", "name": "stakingToken", "type": "address" },
        { "internalType": "address", "name": "rewardToken", "type": "address" },
        { "internalType": "uint256", "name": "totalStaked", "type": "uint256" },
        { "internalType": "uint256", "name": "rewardRate", "type": "uint256" },
        { "internalType": "uint256", "name": "lockDuration", "type": "uint256" },
        { "internalType": "uint256", "name": "lastUpdateTime", "type": "uint256" },
        { "internalType": "uint256", "name": "rewardPerTokenStored", "type": "uint256" },
        { "internalType": "bool", "name": "isActive", "type": "bool" },
        { "internalType": "uint256", "name": "depositFee", "type": "uint256" },
        { "internalType": "uint256", "name": "withdrawFee", "type": "uint256" }
      ],
      "internalType": "struct IStakeFlowStaking.Pool",
      "name": "",
      "type": "tuple"
    }],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [{ "internalType": "uint256", "name": "_poolId", "type": "uint256" }],
    "name": "getPoolAPY",
    "outputs": [{ "internalType": "uint256", "name": "", "type": "uint256" }],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "poolCount",
    "outputs": [{ "internalType": "uint256", "name": "", "type": "uint256" }],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [{ "internalType": "address", "name": "_user", "type": "address" }],
    "name": "getUserPositions",
    "outputs": [
      { "internalType": "uint256[]", "name": "poolIds", "type": "uint256[]" },
      { "internalType": "uint256[]", "name": "stakes", "type": "uint256[]" },
      { "internalType": "uint256[]", "name": "rewards", "type": "uint256[]" }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "anonymous": false,
    "inputs": [
      { "indexed": true, "internalType": "address", "name": "user", "type": "address" },
      { "indexed": true, "internalType": "uint256", "name": "poolId", "type": "uint256" },
      { "indexed": false, "internalType": "uint256", "name": "amount", "type": "uint256" },
      { "indexed": false, "internalType": "uint256", "name": "timestamp", "type": "uint256" }
    ],
    "name": "Staked",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      { "indexed": true, "internalType": "address", "name": "user", "type": "address" },
      { "indexed": true, "internalType": "uint256", "name": "poolId", "type": "uint256" },
      { "indexed": false, "internalType": "uint256", "name": "amount", "type": "uint256" },
      { "indexed": false, "internalType": "uint256", "name": "rewardAmount", "type": "uint256" },
      { "indexed": false, "internalType": "uint256", "name": "timestamp", "type": "uint256" }
    ],
    "name": "Withdrawn",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      { "indexed": true, "internalType": "address", "name": "user", "type": "address" },
      { "indexed": true, "internalType": "uint256", "name": "poolId", "type": "uint256" },
      { "indexed": false, "internalType": "uint256", "name": "rewardAmount", "type": "uint256" },
      { "indexed": false, "internalType": "uint256", "name": "timestamp", "type": "uint256" }
    ],
    "name": "RewardClaimed",
    "type": "event"
  }
] as const;

export const ERC20ABI = [
  {
    "inputs": [
      { "name": "owner", "type": "address" },
      { "name": "spender", "type": "address" }
    ],
    "name": "allowance",
    "outputs": [{ "name": "", "type": "uint256" }],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      { "name": "spender", "type": "address" },
      { "name": "amount", "type": "uint256" }
    ],
    "name": "approve",
    "outputs": [{ "name": "", "type": "bool" }],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [{ "name": "account", "type": "address" }],
    "name": "balanceOf",
    "outputs": [{ "name": "", "type": "uint256" }],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "decimals",
    "outputs": [{ "name": "", "type": "uint8" }],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "symbol",
    "outputs": [{ "name": "", "type": "string" }],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "name",
    "outputs": [{ "name": "", "type": "string" }],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "totalSupply",
    "outputs": [{ "name": "", "type": "uint256" }],
    "stateMutability": "view",
    "type": "function"
  }
] as const;
