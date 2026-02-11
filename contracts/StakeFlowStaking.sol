// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./IStakeFlowStaking.sol";

/**
 * @title StakeFlowStaking
 * @notice Main staking contract for StakeFlow DeFi protocol
 * @dev Implements multi-pool staking with time-weighted rewards, compound interest,
 *      and emergency withdrawal mechanisms. Gas-optimized with storage packing.
 * 
 * Security Features:
 * - ReentrancyGuard: Prevents reentrancy attacks
 * - Pausable: Emergency pause functionality
 * - Access control: Owner-only admin functions
 * - Input validation: Comprehensive parameter checks
 * - Overflow protection: Solidity 0.8+ built-in checks + Math library
 */
contract StakeFlowStaking is IStakeFlowStaking, ReentrancyGuard, Pausable, Ownable {
    using SafeERC20 for IERC20;
    using Math for uint256;

    /*//////////////////////////////////////////////////////////////
                            CONSTANTS
    //////////////////////////////////////////////////////////////*/
    
    /// @notice Basis points denominator (100% = 10000)
    uint256 private constant BASIS_POINTS = 10000;
    
    /// @notice Precision for reward calculations
    uint256 private constant REWARD_PRECISION = 1e12;
    
    /// @notice Maximum deposit fee (5%)
    uint256 private constant MAX_DEPOSIT_FEE = 500;
    
    /// @notice Maximum withdrawal fee (5%)
    uint256 private constant MAX_WITHDRAW_FEE = 500;
    
    /// @notice Emergency withdrawal penalty (10%)
    uint256 private constant EMERGENCY_PENALTY = 1000;
    
    /// @notice Seconds in a year (365 days)
    uint256 private constant SECONDS_PER_YEAR = 365 days;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    
    /// @notice Array of all staking pools
    Pool[] public pools;
    
    /// @notice User staking info: poolId => user => UserInfo
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    
    /// @notice Total fees collected per token
    mapping(address => uint256) public collectedFees;
    
    /// @notice Whitelisted staking tokens
    mapping(address => bool) public whitelistedTokens;
    
    /// @notice Reward distributor address (can add rewards)
    address public rewardDistributor;
    
    /// @notice Protocol fee recipient
    address public feeRecipient;
    
    /// @notice Pool count
    uint256 public override poolCount;

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/
    
    modifier poolExists(uint256 _poolId) {
        require(_poolId < pools.length, "StakeFlow: pool does not exist");
        _;
    }
    
    modifier onlyDistributor() {
        require(
            msg.sender == rewardDistributor || msg.sender == owner(),
            "StakeFlow: not authorized"
        );
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    
    constructor(address _initialOwner, address _feeRecipient) Ownable(_initialOwner) {
        require(_feeRecipient != address(0), "StakeFlow: invalid fee recipient");
        feeRecipient = _feeRecipient;
        rewardDistributor = _initialOwner;
    }

    /*//////////////////////////////////////////////////////////////
                        ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    
    /**
     * @notice Set reward distributor address
     * @param _distributor New distributor address
     */
    function setRewardDistributor(address _distributor) external onlyOwner {
        require(_distributor != address(0), "StakeFlow: invalid address");
        rewardDistributor = _distributor;
    }
    
    /**
     * @notice Set fee recipient address
     * @param _recipient New fee recipient
     */
    function setFeeRecipient(address _recipient) external onlyOwner {
        require(_recipient != address(0), "StakeFlow: invalid address");
        feeRecipient = _recipient;
    }
    
    /**
     * @notice Whitelist/unwhitelist a staking token
     * @param _token Token address
     * @param _status Whitelist status
     */
    function setTokenWhitelist(address _token, bool _status) external onlyOwner {
        require(_token != address(0), "StakeFlow: invalid token");
        whitelistedTokens[_token] = _status;
    }
    
    /**
     * @notice Pause the entire protocol
     */
    function pause() external onlyOwner {
        _pause();
    }
    
    /**
     * @notice Unpause the entire protocol
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /*//////////////////////////////////////////////////////////////
                        POOL MANAGEMENT
    //////////////////////////////////////////////////////////////*/
    
    /// @inheritdoc IStakeFlowStaking
    function createPool(
        address _stakingToken,
        address _rewardToken,
        uint256 _rewardRate,
        uint256 _lockDuration,
        uint256 _depositFee,
        uint256 _withdrawFee
    ) external override onlyOwner returns (uint256 poolId) {
        require(_stakingToken != address(0), "StakeFlow: invalid staking token");
        require(_rewardToken != address(0), "StakeFlow: invalid reward token");
        require(_depositFee <= MAX_DEPOSIT_FEE, "StakeFlow: deposit fee too high");
        require(_withdrawFee <= MAX_WITHDRAW_FEE, "StakeFlow: withdraw fee too high");
        
        // Optional: require whitelisted tokens
        // require(whitelistedTokens[_stakingToken], "StakeFlow: token not whitelisted");
        
        poolId = pools.length;
        
        pools.push(Pool({
            stakingToken: _stakingToken,
            rewardToken: _rewardToken,
            totalStaked: 0,
            rewardRate: _rewardRate,
            lockDuration: _lockDuration,
            lastUpdateTime: block.timestamp,
            rewardPerTokenStored: 0,
            isActive: true,
            depositFee: _depositFee,
            withdrawFee: _withdrawFee
        }));
        
        poolCount = pools.length;
        
        emit PoolCreated(
            poolId,
            _stakingToken,
            _rewardToken,
            _rewardRate,
            _lockDuration
        );
        
        return poolId;
    }
    
    /// @inheritdoc IStakeFlowStaking
    function updatePool(
        uint256 _poolId,
        uint256 _rewardRate,
        uint256 _lockDuration
    ) external override onlyOwner poolExists(_poolId) {
        _updatePoolRewards(_poolId);
        
        Pool storage pool = pools[_poolId];
        pool.rewardRate = _rewardRate;
        pool.lockDuration = _lockDuration;
        
        emit PoolUpdated(_poolId, _rewardRate, _lockDuration);
    }
    
    /// @inheritdoc IStakeFlowStaking
    function setPoolPause(uint256 _poolId, bool _paused) external override onlyOwner poolExists(_poolId) {
        pools[_poolId].isActive = !_paused;
    }
    
    /// @inheritdoc IStakeFlowStaking
    function addRewards(
        uint256 _poolId,
        uint256 _amount,
        uint256 _duration
    ) external override onlyDistributor poolExists(_poolId) {
        require(_amount > 0, "StakeFlow: amount must be > 0");
        require(_duration > 0, "StakeFlow: duration must be > 0");
        
        Pool storage pool = pools[_poolId];
        require(pool.isActive, "StakeFlow: pool not active");
        
        _updatePoolRewards(_poolId);
        
        // Transfer reward tokens from distributor
        IERC20(pool.rewardToken).safeTransferFrom(msg.sender, address(this), _amount);
        
        // Calculate new reward rate: amount / duration (scaled)
        uint256 newRewardRate = (_amount * REWARD_PRECISION) / _duration;
        pool.rewardRate = newRewardRate;
        
        emit RewardsAdded(_poolId, _amount, _duration);
    }

    /*//////////////////////////////////////////////////////////////
                        STAKING FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    
    /// @inheritdoc IStakeFlowStaking
    function stake(
        uint256 _poolId,
        uint256 _amount
    ) external override nonReentrant whenNotPaused poolExists(_poolId) {
        require(_amount > 0, "StakeFlow: amount must be > 0");
        
        Pool storage pool = pools[_poolId];
        require(pool.isActive, "StakeFlow: pool not active");
        
        _updatePoolRewards(_poolId);
        
        UserInfo storage user = userInfo[_poolId][msg.sender];
        
        // Calculate pending rewards before updating stake
        if (user.stakedAmount > 0) {
            uint256 pending = _calculatePendingRewards(_poolId, msg.sender);
            user.pendingRewards += pending;
        }
        
        // Update reward debt
        user.rewardDebt = (user.stakedAmount * pool.rewardPerTokenStored) / REWARD_PRECISION;
        
        // Calculate deposit fee
        uint256 fee = (_amount * pool.depositFee) / BASIS_POINTS;
        uint256 stakeAmount = _amount - fee;
        
        // Update user info
        user.stakedAmount += stakeAmount;
        user.lastStakeTime = block.timestamp;
        user.unlockTime = block.timestamp + pool.lockDuration;
        
        // Update pool total
        pool.totalStaked += stakeAmount;
        
        // Collect fee
        if (fee > 0) {
            collectedFees[pool.stakingToken] += fee;
        }
        
        // Transfer tokens from user
        IERC20(pool.stakingToken).safeTransferFrom(msg.sender, address(this), _amount);
        
        emit Staked(msg.sender, _poolId, stakeAmount, block.timestamp);
    }
    
    /// @inheritdoc IStakeFlowStaking
    function withdraw(
        uint256 _poolId,
        uint256 _amount
    ) external override nonReentrant whenNotPaused poolExists(_poolId) {
        require(_amount > 0, "StakeFlow: amount must be > 0");
        
        UserInfo storage user = userInfo[_poolId][msg.sender];
        require(user.stakedAmount >= _amount, "StakeFlow: insufficient balance");
        require(block.timestamp >= user.unlockTime, "StakeFlow: tokens locked");
        
        Pool storage pool = pools[_poolId];
        
        _updatePoolRewards(_poolId);
        
        // Calculate rewards
        uint256 pending = _calculatePendingRewards(_poolId, msg.sender);
        uint256 totalRewards = user.pendingRewards + pending;
        
        // Calculate withdrawal fee
        uint256 fee = (_amount * pool.withdrawFee) / BASIS_POINTS;
        uint256 withdrawAmount = _amount - fee;
        
        // Update user info
        user.stakedAmount -= _amount;
        user.pendingRewards = 0;
        user.rewardDebt = (user.stakedAmount * pool.rewardPerTokenStored) / REWARD_PRECISION;
        user.unlockTime = user.stakedAmount > 0 ? block.timestamp + pool.lockDuration : 0;
        
        // Update pool total
        pool.totalStaked -= _amount;
        
        // Collect fee
        if (fee > 0) {
            collectedFees[pool.stakingToken] += fee;
        }
        
        // Transfer staking tokens
        IERC20(pool.stakingToken).safeTransfer(msg.sender, withdrawAmount);
        
        // Transfer rewards if any
        if (totalRewards > 0) {
            // Ensure we have enough reward tokens
            uint256 rewardBalance = IERC20(pool.rewardToken).balanceOf(address(this));
            uint256 actualRewards = totalRewards > rewardBalance ? rewardBalance : totalRewards;
            
            if (actualRewards > 0) {
                IERC20(pool.rewardToken).safeTransfer(msg.sender, actualRewards);
            }
        }
        
        emit Withdrawn(msg.sender, _poolId, withdrawAmount, totalRewards, block.timestamp);
    }
    
    /// @inheritdoc IStakeFlowStaking
    function emergencyWithdraw(
        uint256 _poolId
    ) external override nonReentrant poolExists(_poolId) {
        UserInfo storage user = userInfo[_poolId][msg.sender];
        uint256 amount = user.stakedAmount;
        require(amount > 0, "StakeFlow: no stake to withdraw");
        
        Pool storage pool = pools[_poolId];
        
        // Calculate penalty (user forfeits rewards + pays penalty)
        uint256 penalty = (amount * EMERGENCY_PENALTY) / BASIS_POINTS;
        uint256 withdrawAmount = amount - penalty;
        
        // Reset user info (rewards are forfeited)
        user.stakedAmount = 0;
        user.pendingRewards = 0;
        user.rewardDebt = 0;
        user.unlockTime = 0;
        
        // Update pool total
        pool.totalStaked -= amount;
        
        // Collect penalty as fee
        collectedFees[pool.stakingToken] += penalty;
        
        // Transfer tokens
        IERC20(pool.stakingToken).safeTransfer(msg.sender, withdrawAmount);
        
        emit EmergencyWithdrawn(msg.sender, _poolId, withdrawAmount, penalty);
    }
    
    /// @inheritdoc IStakeFlowStaking
    function claimRewards(
        uint256 _poolId
    ) external override nonReentrant whenNotPaused poolExists(_poolId) {
        Pool storage pool = pools[_poolId];
        UserInfo storage user = userInfo[_poolId][msg.sender];
        
        _updatePoolRewards(_poolId);
        
        uint256 pending = _calculatePendingRewards(_poolId, msg.sender);
        uint256 totalRewards = user.pendingRewards + pending;
        require(totalRewards > 0, "StakeFlow: no rewards to claim");
        
        // Reset pending rewards
        user.pendingRewards = 0;
        user.rewardDebt = (user.stakedAmount * pool.rewardPerTokenStored) / REWARD_PRECISION;
        
        // Transfer rewards
        uint256 rewardBalance = IERC20(pool.rewardToken).balanceOf(address(this));
        uint256 actualRewards = totalRewards > rewardBalance ? rewardBalance : totalRewards;
        
        require(actualRewards > 0, "StakeFlow: insufficient reward balance");
        
        IERC20(pool.rewardToken).safeTransfer(msg.sender, actualRewards);
        
        emit RewardClaimed(msg.sender, _poolId, actualRewards, block.timestamp);
    }
    
    /// @inheritdoc IStakeFlowStaking
    function compound(
        uint256 _poolId
    ) external override nonReentrant whenNotPaused poolExists(_poolId) {
        Pool storage pool = pools[_poolId];
        UserInfo storage user = userInfo[_poolId][msg.sender];
        
        require(pool.stakingToken == pool.rewardToken, "StakeFlow: different tokens");
        
        _updatePoolRewards(_poolId);
        
        uint256 pending = _calculatePendingRewards(_poolId, msg.sender);
        uint256 totalRewards = user.pendingRewards + pending;
        require(totalRewards > 0, "StakeFlow: no rewards to compound");
        
        // Reset pending rewards
        user.pendingRewards = 0;
        
        // Add rewards to stake
        user.stakedAmount += totalRewards;
        pool.totalStaked += totalRewards;
        
        user.rewardDebt = (user.stakedAmount * pool.rewardPerTokenStored) / REWARD_PRECISION;
        
        emit Staked(msg.sender, _poolId, totalRewards, block.timestamp);
        emit RewardClaimed(msg.sender, _poolId, totalRewards, block.timestamp);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    
    /**
     * @notice Update reward variables for a pool
     * @param _poolId ID of the pool
     */
    function _updatePoolRewards(uint256 _poolId) internal {
        Pool storage pool = pools[_poolId];
        
        if (block.timestamp <= pool.lastUpdateTime) {
            return;
        }
        
        if (pool.totalStaked == 0) {
            pool.lastUpdateTime = block.timestamp;
            return;
        }
        
        uint256 timeElapsed = block.timestamp - pool.lastUpdateTime;
        uint256 reward = timeElapsed * pool.rewardRate;
        
        pool.rewardPerTokenStored += (reward * REWARD_PRECISION) / pool.totalStaked;
        pool.lastUpdateTime = block.timestamp;
    }
    
    /**
     * @notice Calculate pending rewards for a user
     * @param _poolId ID of the pool
     * @param _user Address of the user
     * @return Pending reward amount
     */
    function _calculatePendingRewards(
        uint256 _poolId,
        address _user
    ) internal view returns (uint256) {
        Pool storage pool = pools[_poolId];
        UserInfo storage user = userInfo[_poolId][_user];
        
        uint256 rewardPerToken = pool.rewardPerTokenStored;
        
        if (block.timestamp > pool.lastUpdateTime && pool.totalStaked > 0) {
            uint256 timeElapsed = block.timestamp - pool.lastUpdateTime;
            uint256 reward = timeElapsed * pool.rewardRate;
            rewardPerToken += (reward * REWARD_PRECISION) / pool.totalStaked;
        }
        
        return ((user.stakedAmount * rewardPerToken) / REWARD_PRECISION) - user.rewardDebt;
    }

    /*//////////////////////////////////////////////////////////////
                        VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    
    /// @inheritdoc IStakeFlowStaking
    function pendingRewards(
        uint256 _poolId,
        address _user
    ) external view override poolExists(_poolId) returns (uint256) {
        UserInfo storage user = userInfo[_poolId][_user];
        return user.pendingRewards + _calculatePendingRewards(_poolId, _user);
    }
    
    /// @inheritdoc IStakeFlowStaking
    function getUserInfo(
        uint256 _poolId,
        address _user
    ) external view override poolExists(_poolId) returns (UserInfo memory) {
        return userInfo[_poolId][_user];
    }
    
    /// @inheritdoc IStakeFlowStaking
    function getPool(uint256 _poolId) external view override poolExists(_poolId) returns (Pool memory) {
        return pools[_poolId];
    }
    
    /// @inheritdoc IStakeFlowStaking
    function getPoolAPY(uint256 _poolId) external view override poolExists(_poolId) returns (uint256) {
        Pool storage pool = pools[_poolId];
        
        if (pool.totalStaked == 0) {
            return 0;
        }
        
        // APY = (rewardRate * secondsPerYear * rewardTokenPrice) / (totalStaked * stakeTokenPrice) * 100
        // Simplified: assuming 1:1 price ratio
        uint256 yearlyRewards = pool.rewardRate * SECONDS_PER_YEAR;
        uint256 apy = (yearlyRewards * 10000) / (pool.totalStaked * REWARD_PRECISION);
        
        return apy;
    }
    
    /// @inheritdoc IStakeFlowStaking
    function withdrawFees(address _token, uint256 _amount) external override onlyOwner {
        require(_amount <= collectedFees[_token], "StakeFlow: insufficient fees");
        collectedFees[_token] -= _amount;
        IERC20(_token).safeTransfer(feeRecipient, _amount);
        emit FeesCollected(_token, _amount, feeRecipient);
    }
    
    /**
     * @notice Get all active pool IDs
     * @return Array of pool IDs
     */
    function getActivePools() external view returns (uint256[] memory) {
        uint256 activeCount = 0;
        for (uint256 i = 0; i < pools.length; i++) {
            if (pools[i].isActive) {
                activeCount++;
            }
        }
        
        uint256[] memory activePools = new uint256[](activeCount);
        uint256 index = 0;
        for (uint256 i = 0; i < pools.length; i++) {
            if (pools[i].isActive) {
                activePools[index] = i;
                index++;
            }
        }
        
        return activePools;
    }
    
    /**
     * @notice Get user's positions across all pools
     * @param _user User address
     * @return poolIds Array of pool IDs where user has stake
     * @return stakes Array of staked amounts
     * @return rewards Array of pending rewards
     */
    function getUserPositions(
        address _user
    ) external view returns (
        uint256[] memory poolIds,
        uint256[] memory stakes,
        uint256[] memory rewards
    ) {
        uint256 positionCount = 0;
        for (uint256 i = 0; i < pools.length; i++) {
            if (userInfo[i][_user].stakedAmount > 0) {
                positionCount++;
            }
        }
        
        poolIds = new uint256[](positionCount);
        stakes = new uint256[](positionCount);
        rewards = new uint256[](positionCount);
        
        uint256 index = 0;
        for (uint256 i = 0; i < pools.length; i++) {
            UserInfo storage user = userInfo[i][_user];
            if (user.stakedAmount > 0) {
                poolIds[index] = i;
                stakes[index] = user.stakedAmount;
                rewards[index] = user.pendingRewards + _calculatePendingRewards(i, _user);
                index++;
            }
        }
        
        return (poolIds, stakes, rewards);
    }
}
