// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IStakeFlowStaking
 * @notice Interface for StakeFlow staking contract
 * @dev Defines all external functions and events for the staking protocol
 */
interface IStakeFlowStaking {
    
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    
    /// @notice Emitted when a user stakes tokens
    event Staked(
        address indexed user,
        uint256 indexed poolId,
        uint256 amount,
        uint256 timestamp
    );
    
    /// @notice Emitted when a user withdraws staked tokens
    event Withdrawn(
        address indexed user,
        uint256 indexed poolId,
        uint256 amount,
        uint256 rewardAmount,
        uint256 timestamp
    );
    
    /// @notice Emitted when a user claims rewards
    event RewardClaimed(
        address indexed user,
        uint256 indexed poolId,
        uint256 rewardAmount,
        uint256 timestamp
    );
    
    /// @notice Emitted when a new staking pool is created
    event PoolCreated(
        uint256 indexed poolId,
        address indexed stakingToken,
        address rewardToken,
        uint256 rewardRate,
        uint256 lockDuration
    );
    
    /// @notice Emitted when pool parameters are updated
    event PoolUpdated(
        uint256 indexed poolId,
        uint256 newRewardRate,
        uint256 newLockDuration
    );
    
    /// @notice Emitted when rewards are added to a pool
    event RewardsAdded(
        uint256 indexed poolId,
        uint256 amount,
        uint256 duration
    );
    
    /// @notice Emitted when emergency withdrawal occurs
    event EmergencyWithdrawn(
        address indexed user,
        uint256 indexed poolId,
        uint256 amount,
        uint256 penalty
    );
    
    /// @notice Emitted when protocol fees are collected
    event FeesCollected(
        address indexed token,
        uint256 amount,
        address indexed recipient
    );

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/
    
    struct Pool {
        address stakingToken;      // Token users stake
        address rewardToken;       // Token distributed as rewards
        uint256 totalStaked;       // Total tokens staked in pool
        uint256 rewardRate;        // Rewards per second (scaled by 1e12)
        uint256 lockDuration;      // Minimum lock period (seconds)
        uint256 lastUpdateTime;    // Last time rewards calculated
        uint256 rewardPerTokenStored; // Accumulated rewards per token
        bool isActive;             // Pool active status
        uint256 depositFee;        // Deposit fee in basis points (100 = 1%)
        uint256 withdrawFee;       // Withdraw fee in basis points
    }
    
    struct UserInfo {
        uint256 stakedAmount;      // User's staked tokens
        uint256 rewardDebt;        // Rewards already claimed
        uint256 pendingRewards;    // Unclaimed rewards
        uint256 lastStakeTime;     // When user last staked
        uint256 unlockTime;        // When tokens can be withdrawn
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    
    /**
     * @notice Create a new staking pool
     * @param _stakingToken Token users will stake
     * @param _rewardToken Token distributed as rewards
     * @param _rewardRate Rewards per second (scaled by 1e12)
     * @param _lockDuration Minimum lock period in seconds
     * @param _depositFee Deposit fee in basis points
     * @param _withdrawFee Withdraw fee in basis points
     * @return poolId ID of the created pool
     */
    function createPool(
        address _stakingToken,
        address _rewardToken,
        uint256 _rewardRate,
        uint256 _lockDuration,
        uint256 _depositFee,
        uint256 _withdrawFee
    ) external returns (uint256 poolId);
    
    /**
     * @notice Stake tokens into a pool
     * @param _poolId ID of the pool
     * @param _amount Amount to stake
     */
    function stake(uint256 _poolId, uint256 _amount) external;
    
    /**
     * @notice Withdraw staked tokens and claim rewards
     * @param _poolId ID of the pool
     * @param _amount Amount to withdraw
     */
    function withdraw(uint256 _poolId, uint256 _amount) external;
    
    /**
     * @notice Emergency withdraw without rewards (with penalty)
     * @param _poolId ID of the pool
     */
    function emergencyWithdraw(uint256 _poolId) external;
    
    /**
     * @notice Claim pending rewards without withdrawing stake
     * @param _poolId ID of the pool
     */
    function claimRewards(uint256 _poolId) external;
    
    /**
     * @notice Compound rewards back into stake
     * @param _poolId ID of the pool
     */
    function compound(uint256 _poolId) external;
    
    /**
     * @notice Add rewards to a pool (only callable by reward distributor)
     * @param _poolId ID of the pool
     * @param _amount Amount of reward tokens to add
     * @param _duration Duration over which rewards will be distributed
     */
    function addRewards(
        uint256 _poolId,
        uint256 _amount,
        uint256 _duration
    ) external;
    
    /**
     * @notice Update pool parameters
     * @param _poolId ID of the pool
     * @param _rewardRate New reward rate
     * @param _lockDuration New lock duration
     */
    function updatePool(
        uint256 _poolId,
        uint256 _rewardRate,
        uint256 _lockDuration
    ) external;
    
    /**
     * @notice Pause/unpause a pool
     * @param _poolId ID of the pool
     * @param _paused New paused state
     */
    function setPoolPause(uint256 _poolId, bool _paused) external;
    
    /**
     * @notice Calculate pending rewards for a user
     * @param _poolId ID of the pool
     * @param _user Address of the user
     * @return Pending reward amount
     */
    function pendingRewards(
        uint256 _poolId,
        address _user
    ) external view returns (uint256);
    
    /**
     * @notice Get user's staking info
     * @param _poolId ID of the pool
     * @param _user Address of the user
     * @return UserInfo struct
     */
    function getUserInfo(
        uint256 _poolId,
        address _user
    ) external view returns (UserInfo memory);
    
    /**
     * @notice Get pool information
     * @param _poolId ID of the pool
     * @return Pool struct
     */
    function getPool(uint256 _poolId) external view returns (Pool memory);
    
    /**
     * @notice Get current APY for a pool (scaled by 100)
     * @param _poolId ID of the pool
     * @return APY in basis points (10000 = 100%)
     */
    function getPoolAPY(uint256 _poolId) external view returns (uint256);
    
    /**
     * @notice Get total number of pools
     * @return Number of pools
     */
    function poolCount() external view returns (uint256);
    
    /**
     * @notice Withdraw collected fees
     * @param _token Token to withdraw
     * @param _amount Amount to withdraw
     */
    function withdrawFees(address _token, uint256 _amount) external;
}
