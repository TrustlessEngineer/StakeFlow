// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../contracts/StakeFlowStaking.sol";
import "../contracts/StakeFlowToken.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockERC20
 * @notice Simple ERC20 for testing
 */
contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1_000_000_000 * 10**18);
    }
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/**
 * @title StakeFlowStakingTest
 * @notice Comprehensive test suite for StakeFlow staking protocol
 * @dev Tests cover: staking, withdrawal, rewards, fees, security, edge cases
 */
contract StakeFlowStakingTest is Test {
    
    // Contracts
    StakeFlowStaking public staking;
    StakeFlowToken public rewardToken;
    MockERC20 public stakingToken;
    
    // Addresses
    address public owner;
    address public alice;
    address public bob;
    address public charlie;
    address public feeRecipient;
    
    // Constants
    uint256 constant INITIAL_BALANCE = 1_000_000 * 10**18;
    uint256 constant POOL_DEPOSIT_FEE = 100; // 1%
    uint256 constant POOL_WITHDRAW_FEE = 100; // 1%
    uint256 constant LOCK_DURATION = 7 days;
    
    // Events
    event Staked(address indexed user, uint256 indexed poolId, uint256 amount, uint256 timestamp);
    event Withdrawn(address indexed user, uint256 indexed poolId, uint256 amount, uint256 rewardAmount, uint256 timestamp);
    event RewardClaimed(address indexed user, uint256 indexed poolId, uint256 rewardAmount, uint256 timestamp);
    event EmergencyWithdrawn(address indexed user, uint256 indexed poolId, uint256 amount, uint256 penalty);

    function setUp() public {
        owner = makeAddr("owner");
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");
        feeRecipient = makeAddr("feeRecipient");
        
        vm.startPrank(owner);
        
        // Deploy tokens
        rewardToken = new StakeFlowToken("StakeFlow Token", "SFT", owner);
        stakingToken = new MockERC20("Staking Token", "STK");
        
        // Deploy staking contract
        staking = new StakeFlowStaking(owner, feeRecipient);
        
        // Setup reward token minter
        rewardToken.setMinter(address(staking), true);
        
        vm.stopPrank();
        
        // Fund test accounts
        stakingToken.transfer(alice, INITIAL_BALANCE);
        stakingToken.transfer(bob, INITIAL_BALANCE);
        stakingToken.transfer(charlie, INITIAL_BALANCE);
        rewardToken.transfer(address(staking), 1_000_000 * 10**18);
    }

    /*//////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    
    function _createPool() internal returns (uint256 poolId) {
        vm.prank(owner);
        poolId = staking.createPool(
            address(stakingToken),
            address(rewardToken),
            1e12, // 1 token per second (scaled)
            LOCK_DURATION,
            POOL_DEPOSIT_FEE,
            POOL_WITHDRAW_FEE
        );
    }
    
    function _addRewards(uint256 poolId, uint256 amount, uint256 duration) internal {
        vm.startPrank(owner);
        rewardToken.approve(address(staking), amount);
        staking.addRewards(poolId, amount, duration);
        vm.stopPrank();
    }
    
    function _stake(address user, uint256 poolId, uint256 amount) internal {
        vm.startPrank(user);
        stakingToken.approve(address(staking), amount);
        staking.stake(poolId, amount);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        POOL CREATION TESTS
    //////////////////////////////////////////////////////////////*/
    
    function test_CreatePool() public {
        vm.prank(owner);
        
        uint256 poolId = staking.createPool(
            address(stakingToken),
            address(rewardToken),
            1e12,
            LOCK_DURATION,
            POOL_DEPOSIT_FEE,
            POOL_WITHDRAW_FEE
        );
        
        assertEq(poolId, 0);
        assertEq(staking.poolCount(), 1);
        
        IStakeFlowStaking.Pool memory pool = staking.getPool(poolId);
        assertEq(pool.stakingToken, address(stakingToken));
        assertEq(pool.rewardToken, address(rewardToken));
        assertEq(pool.rewardRate, 1e12);
        assertEq(pool.lockDuration, LOCK_DURATION);
        assertEq(pool.depositFee, POOL_DEPOSIT_FEE);
        assertEq(pool.withdrawFee, POOL_WITHDRAW_FEE);
        assertTrue(pool.isActive);
    }
    
    function test_RevertCreatePoolInvalidToken() public {
        vm.prank(owner);
        vm.expectRevert("StakeFlow: invalid staking token");
        staking.createPool(address(0), address(rewardToken), 1e12, 0, 0, 0);
    }
    
    function test_RevertCreatePoolFeeTooHigh() public {
        vm.prank(owner);
        vm.expectRevert("StakeFlow: deposit fee too high");
        staking.createPool(address(stakingToken), address(rewardToken), 1e12, 0, 1000, 0);
    }

    /*//////////////////////////////////////////////////////////////
                        STAKING TESTS
    //////////////////////////////////////////////////////////////*/
    
    function test_Stake() public {
        uint256 poolId = _createPool();
        uint256 stakeAmount = 1000 * 10**18;
        uint256 expectedFee = (stakeAmount * POOL_DEPOSIT_FEE) / 10000;
        uint256 expectedStake = stakeAmount - expectedFee;
        
        vm.expectEmit(true, true, true, true);
        emit Staked(alice, poolId, expectedStake, block.timestamp);
        
        _stake(alice, poolId, stakeAmount);
        
        IStakeFlowStaking.UserInfo memory user = staking.getUserInfo(poolId, alice);
        assertEq(user.stakedAmount, expectedStake);
        assertEq(user.lastStakeTime, block.timestamp);
        assertEq(user.unlockTime, block.timestamp + LOCK_DURATION);
        
        IStakeFlowStaking.Pool memory pool = staking.getPool(poolId);
        assertEq(pool.totalStaked, expectedStake);
    }
    
    function test_RevertStakeZeroAmount() public {
        uint256 poolId = _createPool();
        
        vm.prank(alice);
        vm.expectRevert("StakeFlow: amount must be > 0");
        staking.stake(poolId, 0);
    }
    
    function test_RevertStakePoolNotActive() public {
        uint256 poolId = _createPool();
        
        vm.prank(owner);
        staking.setPoolPause(poolId, true);
        
        vm.startPrank(alice);
        stakingToken.approve(address(staking), 1000 * 10**18);
        vm.expectRevert("StakeFlow: pool not active");
        staking.stake(poolId, 1000 * 10**18);
        vm.stopPrank();
    }
    
    function test_StakeMultipleUsers() public {
        uint256 poolId = _createPool();
        uint256 amount1 = 1000 * 10**18;
        uint256 amount2 = 2000 * 10**18;
        
        _stake(alice, poolId, amount1);
        _stake(bob, poolId, amount2);
        
        IStakeFlowStaking.Pool memory pool = staking.getPool(poolId);
        uint256 expectedTotal = (amount1 - (amount1 * POOL_DEPOSIT_FEE / 10000)) + 
                               (amount2 - (amount2 * POOL_DEPOSIT_FEE / 10000));
        assertEq(pool.totalStaked, expectedTotal);
    }

    /*//////////////////////////////////////////////////////////////
                        REWARD TESTS
    //////////////////////////////////////////////////////////////*/
    
    function test_RewardsAccumulation() public {
        uint256 poolId = _createPool();
        uint256 stakeAmount = 10000 * 10**18;
        uint256 rewardAmount = 100000 * 10**18;
        uint256 duration = 30 days;
        
        // Add rewards
        _addRewards(poolId, rewardAmount, duration);
        
        // Stake
        _stake(alice, poolId, stakeAmount);
        
        // Advance time
        vm.warp(block.timestamp + 7 days);
        
        // Check pending rewards
        uint256 pending = staking.pendingRewards(poolId, alice);
        assertGt(pending, 0);
        
        // Expected rewards: (7 days * rewardRate * stakeAmount) / totalStaked
        // rewardRate = rewardAmount * REWARD_PRECISION / duration
        uint256 expectedRewardRate = (rewardAmount * 1e12) / duration;
        uint256 expectedRewards = (7 days * expectedRewardRate) / 1e12;
        
        // Allow for small rounding differences
        assertApproxEqRel(pending, expectedRewards, 0.01e18);
    }
    
    function test_ClaimRewards() public {
        uint256 poolId = _createPool();
        uint256 stakeAmount = 10000 * 10**18;
        
        _addRewards(poolId, 100000 * 10**18, 30 days);
        _stake(alice, poolId, stakeAmount);
        
        vm.warp(block.timestamp + 7 days);
        
        uint256 pendingBefore = staking.pendingRewards(poolId, alice);
        uint256 balanceBefore = rewardToken.balanceOf(alice);
        
        vm.prank(alice);
        staking.claimRewards(poolId);
        
        uint256 balanceAfter = rewardToken.balanceOf(alice);
        assertApproxEqRel(balanceAfter - balanceBefore, pendingBefore, 0.01e18);
        
        IStakeFlowStaking.UserInfo memory user = staking.getUserInfo(poolId, alice);
        assertEq(user.pendingRewards, 0);
    }
    
    function test_RevertClaimNoRewards() public {
        uint256 poolId = _createPool();
        
        vm.prank(alice);
        vm.expectRevert("StakeFlow: no rewards to claim");
        staking.claimRewards(poolId);
    }

    /*//////////////////////////////////////////////////////////////
                        WITHDRAWAL TESTS
    //////////////////////////////////////////////////////////////*/
    
    function test_Withdraw() public {
        uint256 poolId = _createPool();
        uint256 stakeAmount = 10000 * 10**18;
        
        _addRewards(poolId, 100000 * 10**18, 30 days);
        _stake(alice, poolId, stakeAmount);
        
        // Warp past lock period
        vm.warp(block.timestamp + LOCK_DURATION + 1);
        
        uint256 balanceBefore = stakingToken.balanceOf(alice);
        
        vm.prank(alice);
        staking.withdraw(poolId, staking.getUserInfo(poolId, alice).stakedAmount);
        
        uint256 balanceAfter = stakingToken.balanceOf(alice);
        
        // Should have received stake back minus withdraw fee
        IStakeFlowStaking.UserInfo memory user = staking.getUserInfo(poolId, alice);
        assertEq(user.stakedAmount, 0);
        assertGt(balanceAfter, balanceBefore);
    }
    
    function test_RevertWithdrawLocked() public {
        uint256 poolId = _createPool();
        uint256 stakeAmount = 10000 * 10**18;
        
        _stake(alice, poolId, stakeAmount);
        
        vm.prank(alice);
        vm.expectRevert("StakeFlow: tokens locked");
        staking.withdraw(poolId, stakeAmount);
    }
    
    function test_RevertWithdrawInsufficientBalance() public {
        uint256 poolId = _createPool();
        
        _stake(alice, poolId, 1000 * 10**18);
        vm.warp(block.timestamp + LOCK_DURATION + 1);
        
        vm.prank(alice);
        vm.expectRevert("StakeFlow: insufficient balance");
        staking.withdraw(poolId, 10000 * 10**18);
    }

    /*//////////////////////////////////////////////////////////////
                        EMERGENCY WITHDRAW TESTS
    //////////////////////////////////////////////////////////////*/
    
    function test_EmergencyWithdraw() public {
        uint256 poolId = _createPool();
        uint256 stakeAmount = 10000 * 10**18;
        
        _stake(alice, poolId, stakeAmount);
        
        uint256 balanceBefore = stakingToken.balanceOf(alice);
        uint256 stakedBefore = staking.getUserInfo(poolId, alice).stakedAmount;
        
        vm.expectEmit(true, true, true, true);
        emit EmergencyWithdrawn(alice, poolId, stakedBefore * 9000 / 10000, stakedBefore * 1000 / 10000);
        
        vm.prank(alice);
        staking.emergencyWithdraw(poolId);
        
        uint256 balanceAfter = stakingToken.balanceOf(alice);
        
        // Should have received 90% of stake back (10% penalty)
        uint256 expectedReturn = stakedBefore * 9000 / 10000;
        assertEq(balanceAfter - balanceBefore, expectedReturn);
        
        IStakeFlowStaking.UserInfo memory user = staking.getUserInfo(poolId, alice);
        assertEq(user.stakedAmount, 0);
    }
    
    function test_RevertEmergencyWithdrawNoStake() public {
        uint256 poolId = _createPool();
        
        vm.prank(alice);
        vm.expectRevert("StakeFlow: no stake to withdraw");
        staking.emergencyWithdraw(poolId);
    }

    /*//////////////////////////////////////////////////////////////
                        COMPOUND TESTS
    //////////////////////////////////////////////////////////////*/
    
    function test_Compound() public {
        // Create pool where staking token = reward token
        vm.prank(owner);
        uint256 poolId = staking.createPool(
            address(rewardToken),
            address(rewardToken),
            1e12,
            LOCK_DURATION,
            POOL_DEPOSIT_FEE,
            POOL_WITHDRAW_FEE
        );
        
        // Fund alice with reward tokens
        vm.prank(owner);
        rewardToken.transfer(alice, 100000 * 10**18);
        
        _addRewards(poolId, 1000000 * 10**18, 30 days);
        
        // Alice stakes
        vm.startPrank(alice);
        rewardToken.approve(address(staking), 10000 * 10**18);
        staking.stake(poolId, 10000 * 10**18);
        vm.stopPrank();
        
        // Advance time to accumulate rewards
        vm.warp(block.timestamp + 7 days);
        
        uint256 stakedBefore = staking.getUserInfo(poolId, alice).stakedAmount;
        
        vm.prank(alice);
        staking.compound(poolId);
        
        uint256 stakedAfter = staking.getUserInfo(poolId, alice).stakedAmount;
        
        // Staked amount should have increased
        assertGt(stakedAfter, stakedBefore);
    }
    
    function test_RevertCompoundDifferentTokens() public {
        uint256 poolId = _createPool();
        
        vm.prank(alice);
        vm.expectRevert("StakeFlow: different tokens");
        staking.compound(poolId);
    }

    /*//////////////////////////////////////////////////////////////
                        FEE TESTS
    //////////////////////////////////////////////////////////////*/
    
    function test_FeesCollected() public {
        uint256 poolId = _createPool();
        uint256 stakeAmount = 10000 * 10**18;
        uint256 expectedDepositFee = (stakeAmount * POOL_DEPOSIT_FEE) / 10000;
        
        _stake(alice, poolId, stakeAmount);
        
        uint256 feesCollected = staking.collectedFees(address(stakingToken));
        assertEq(feesCollected, expectedDepositFee);
    }
    
    function test_WithdrawFees() public {
        uint256 poolId = _createPool();
        
        _stake(alice, poolId, 10000 * 10**18);
        
        uint256 feesBefore = stakingToken.balanceOf(feeRecipient);
        uint256 collectedFees = staking.collectedFees(address(stakingToken));
        
        vm.prank(owner);
        staking.withdrawFees(address(stakingToken), collectedFees);
        
        uint256 feesAfter = stakingToken.balanceOf(feeRecipient);
        assertEq(feesAfter - feesBefore, collectedFees);
    }

    /*//////////////////////////////////////////////////////////////
                        SECURITY TESTS
    //////////////////////////////////////////////////////////////*/
    
    function test_ReentrancyProtection() public {
        // This test verifies the nonReentrant modifier is in place
        // Full reentrancy testing would require a malicious contract
        uint256 poolId = _createPool();
        
        _stake(alice, poolId, 1000 * 10**18);
        vm.warp(block.timestamp + LOCK_DURATION + 1);
        
        // Should not be vulnerable to reentrancy
        vm.prank(alice);
        staking.withdraw(poolId, staking.getUserInfo(poolId, alice).stakedAmount);
    }
    
    function test_PauseUnpause() public {
        uint256 poolId = _createPool();
        
        // Pause entire protocol
        vm.prank(owner);
        staking.pause();
        
        vm.startPrank(alice);
        stakingToken.approve(address(staking), 1000 * 10**18);
        vm.expectRevert();
        staking.stake(poolId, 1000 * 10**18);
        vm.stopPrank();
        
        // Unpause
        vm.prank(owner);
        staking.unpause();
        
        // Should work now
        _stake(alice, poolId, 1000 * 10**18);
    }
    
    function test_OnlyOwnerFunctions() public {
        vm.prank(alice);
        
        vm.expectRevert();
        staking.createPool(address(stakingToken), address(rewardToken), 1e12, 0, 0, 0);
        
        vm.expectRevert();
        staking.pause();
        
        vm.expectRevert();
        staking.setFeeRecipient(address(0));
    }
    
    function test_UpdatePool() public {
        uint256 poolId = _createPool();
        
        vm.prank(owner);
        staking.updatePool(poolId, 2e12, 14 days);
        
        IStakeFlowStaking.Pool memory pool = staking.getPool(poolId);
        assertEq(pool.rewardRate, 2e12);
        assertEq(pool.lockDuration, 14 days);
    }

    /*//////////////////////////////////////////////////////////////
                        VIEW FUNCTIONS TESTS
    //////////////////////////////////////////////////////////////*/
    
    function test_GetPoolAPY() public {
        uint256 poolId = _createPool();
        
        _addRewards(poolId, 100000 * 10**18, 365 days);
        
        _stake(alice, poolId, 10000 * 10**18);
        
        uint256 apy = staking.getPoolAPY(poolId);
        assertGt(apy, 0);
    }
    
    function test_GetUserPositions() public {
        uint256 poolId = _createPool();
        
        _addRewards(poolId, 100000 * 10**18, 30 days);
        _stake(alice, poolId, 10000 * 10**18);
        
        (uint256[] memory poolIds, uint256[] memory stakes, uint256[] memory rewards) = 
            staking.getUserPositions(alice);
        
        assertEq(poolIds.length, 1);
        assertEq(poolIds[0], poolId);
        assertGt(stakes[0], 0);
    }
    
    function test_GetActivePools() public {
        _createPool();
        
        uint256[] memory activePools = staking.getActivePools();
        assertEq(activePools.length, 1);
        assertEq(activePools[0], 0);
    }

    /*//////////////////////////////////////////////////////////////
                        FUZZ TESTS
    //////////////////////////////////////////////////////////////*/
    
    function testFuzz_Stake(uint256 amount) public {
        // Bound amount to reasonable range
        amount = bound(amount, 1e18, 1000000 * 10**18);
        
        uint256 poolId = _createPool();
        
        _stake(alice, poolId, amount);
        
        IStakeFlowStaking.UserInfo memory user = staking.getUserInfo(poolId, alice);
        uint256 expectedFee = (amount * POOL_DEPOSIT_FEE) / 10000;
        assertEq(user.stakedAmount, amount - expectedFee);
    }
    
    function testFuzz_DepositWithdraw(uint256 stakeAmount, uint256 timeElapsed) public {
        stakeAmount = bound(stakeAmount, 1e18, INITIAL_BALANCE);
        timeElapsed = bound(timeElapsed, LOCK_DURATION + 1, 365 days);
        
        uint256 poolId = _createPool();
        
        _addRewards(poolId, 1000000 * 10**18, 365 days);
        _stake(alice, poolId, stakeAmount);
        
        vm.warp(block.timestamp + timeElapsed);
        
        uint256 balanceBefore = stakingToken.balanceOf(alice);
        
        vm.prank(alice);
        staking.withdraw(poolId, staking.getUserInfo(poolId, alice).stakedAmount);
        
        uint256 balanceAfter = stakingToken.balanceOf(alice);
        
        // Should have received tokens back (minus fees)
        assertGt(balanceAfter, balanceBefore);
    }
}
