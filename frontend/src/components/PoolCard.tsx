import { useState } from 'react';
import { useAccount } from 'wagmi';
import { Lock, Unlock, AlertTriangle, Loader2, Zap } from 'lucide-react';
import type { Pool, UserInfo } from '@/hooks/useStaking';
import {
  useTokenBalance,
  useTokenAllowance,
  useApproveToken,
  useStake,
  useWithdraw,
  useClaimRewards,
  useCompound,
  useEmergencyWithdraw,
  usePendingRewards,
} from '@/hooks/useStaking';
import { getContractAddress, formatTokenAmount, parseTokenAmount, formatAPY, formatUnlockTime } from '@/utils/config';
import { formatDuration } from '@/utils/format';

interface PoolCardProps {
  pool: Pool;
  userInfo?: UserInfo;
  onSuccess: () => void;
}

export function PoolCard({ pool, userInfo, onSuccess }: PoolCardProps) {
  const { isConnected, chainId } = useAccount();
  const [stakeAmount, setStakeAmount] = useState('');
  const [withdrawAmount, setWithdrawAmount] = useState('');
  const [activeTab, setActiveTab] = useState<'stake' | 'withdraw'>('stake');

  const stakingAddress = getContractAddress(chainId || 1, 'staking');
  const hasStake = userInfo && userInfo.stakedAmount > 0n;
  const isLocked = userInfo && userInfo.unlockTime > BigInt(Math.floor(Date.now() / 1000));

  // Contract interactions
  const { data: balance } = useTokenBalance(pool.stakingToken);
  const { data: allowance } = useTokenAllowance(pool.stakingToken, stakingAddress);
  const { data: pendingRewards } = usePendingRewards(pool.id);

  const { approve, isPending: isApproving } = useApproveToken();
  const { stake, isPending: isStaking, isSuccess: stakeSuccess } = useStake();
  const { withdraw, isPending: isWithdrawing, isSuccess: withdrawSuccess } = useWithdraw();
  const { claimRewards, isPending: isClaiming, isSuccess: claimSuccess } = useClaimRewards();
  const { compound, isPending: isCompounding, isSuccess: compoundSuccess } = useCompound();
  const { emergencyWithdraw, isPending: isEmergency, isSuccess: emergencySuccess } = useEmergencyWithdraw();

  // Check if approval needed
  const needsApproval = allowance !== undefined && parseTokenAmount(stakeAmount) > allowance;

  // Handle success states
  if (stakeSuccess || withdrawSuccess || claimSuccess || compoundSuccess || emergencySuccess) {
    onSuccess();
  }

  const handleApprove = () => {
    approve(pool.stakingToken, stakingAddress, parseTokenAmount(stakeAmount) * 2n);
  };

  const handleStake = () => {
    if (!stakeAmount || parseFloat(stakeAmount) <= 0) return;
    stake(pool.id, stakeAmount);
    setStakeAmount('');
  };

  const handleWithdraw = () => {
    if (!withdrawAmount || parseFloat(withdrawAmount) <= 0) return;
    withdraw(pool.id, withdrawAmount);
    setWithdrawAmount('');
  };

  const handleClaim = () => {
    claimRewards(pool.id);
  };

  const handleCompound = () => {
    compound(pool.id);
  };

  const handleEmergencyWithdraw = () => {
    if (confirm('Emergency withdraw will forfeit all rewards and incur a 10% penalty. Continue?')) {
      emergencyWithdraw(pool.id);
    }
  };

  const depositFee = (Number(pool.depositFee) / 100).toFixed(2);
  const withdrawFee = (Number(pool.withdrawFee) / 100).toFixed(2);

  return (
    <div className="bg-dark-200 border border-gray-800 rounded-xl overflow-hidden hover:border-gray-700 transition-colors">
      {/* Header */}
      <div className="p-6 border-b border-gray-800">
        <div className="flex items-start justify-between">
          <div className="flex items-center gap-3">
            <div className="w-12 h-12 bg-gradient-to-br from-primary-500 to-secondary-500 rounded-xl flex items-center justify-center">
              <span className="text-white font-bold text-lg">{pool.id}</span>
            </div>
            <div>
              <h3 className="font-semibold text-lg">Pool #{pool.id}</h3>
              <p className="text-gray-500 text-sm">{formatTokenAmount(pool.totalStaked)} Total Staked</p>
            </div>
          </div>
          <div className="text-right">
            <p className="text-2xl font-bold text-green-400">{formatAPY(pool.apy)}</p>
            <p className="text-gray-500 text-sm">APY</p>
          </div>
        </div>

        {/* Pool Details */}
        <div className="grid grid-cols-3 gap-4 mt-6">
          <div className="bg-dark-300 rounded-lg p-3">
            <p className="text-gray-500 text-xs">Lock Period</p>
            <p className="font-medium">{formatDuration(Number(pool.lockDuration))}</p>
          </div>
          <div className="bg-dark-300 rounded-lg p-3">
            <p className="text-gray-500 text-xs">Deposit Fee</p>
            <p className="font-medium">{depositFee}%</p>
          </div>
          <div className="bg-dark-300 rounded-lg p-3">
            <p className="text-gray-500 text-xs">Withdraw Fee</p>
            <p className="font-medium">{withdrawFee}%</p>
          </div>
        </div>

        {/* User Position */}
        {hasStake && (
          <div className="mt-4 p-4 bg-primary-500/5 border border-primary-500/20 rounded-lg">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-gray-500 text-sm">Your Stake</p>
                <p className="text-xl font-semibold">{formatTokenAmount(userInfo.stakedAmount)}</p>
              </div>
              <div className="text-right">
                <p className="text-gray-500 text-sm">Pending Rewards</p>
                <p className="text-xl font-semibold text-primary-400">
                  {pendingRewards ? formatTokenAmount(pendingRewards) : '0'}
                </p>
              </div>
            </div>
            <div className="flex items-center gap-2 mt-2 text-sm">
              {isLocked ? (
                <>
                  <Lock className="w-4 h-4 text-orange-400" />
                  <span className="text-orange-400">
                    Unlocks in {formatUnlockTime(userInfo.unlockTime)}
                  </span>
                </>
              ) : (
                <>
                  <Unlock className="w-4 h-4 text-green-400" />
                  <span className="text-green-400">Unlocked</span>
                </>
              )}
            </div>
          </div>
        )}
      </div>

      {/* Action Tabs */}
      {isConnected ? (
        <div className="p-6">
          <div className="flex gap-2 mb-4">
            <button
              onClick={() => setActiveTab('stake')}
              className={`flex-1 py-2 px-4 rounded-lg font-medium transition-colors ${
                activeTab === 'stake'
                  ? 'bg-primary-500 text-white'
                  : 'bg-dark-300 text-gray-400 hover:text-white'
              }`}
            >
              Stake
            </button>
            <button
              onClick={() => setActiveTab('withdraw')}
              className={`flex-1 py-2 px-4 rounded-lg font-medium transition-colors ${
                activeTab === 'withdraw'
                  ? 'bg-primary-500 text-white'
                  : 'bg-dark-300 text-gray-400 hover:text-white'
              }`}
            >
              Withdraw
            </button>
          </div>

          {activeTab === 'stake' ? (
            <div className="space-y-4">
              <div>
                <div className="flex justify-between text-sm mb-2">
                  <span className="text-gray-500">Amount</span>
                  <span className="text-gray-400">
                    Balance: {balance ? formatTokenAmount(balance) : '0'}
                  </span>
                </div>
                <div className="relative">
                  <input
                    type="number"
                    value={stakeAmount}
                    onChange={(e) => setStakeAmount(e.target.value)}
                    placeholder="0.0"
                    className="w-full bg-dark-300 border border-gray-700 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
                  />
                  <button
                    onClick={() => balance && setStakeAmount(formatTokenAmount(balance))}
                    className="absolute right-3 top-1/2 -translate-y-1/2 text-primary-400 text-sm hover:text-primary-300"
                  >
                    MAX
                  </button>
                </div>
                {parseFloat(stakeAmount) > 0 && (
                  <p className="text-gray-500 text-xs mt-1">
                    You will receive: {formatTokenAmount(parseTokenAmount(stakeAmount) * (10000n - pool.depositFee) / 10000n)} (after {depositFee}% fee)
                  </p>
                )}
              </div>

              {needsApproval ? (
                <button
                  onClick={handleApprove}
                  disabled={isApproving || !stakeAmount}
                  className="w-full bg-primary-500 hover:bg-primary-600 disabled:bg-gray-700 disabled:cursor-not-allowed text-white font-medium py-3 rounded-lg transition-colors flex items-center justify-center gap-2"
                >
                  {isApproving ? (
                    <>
                      <Loader2 className="w-4 h-4 animate-spin" />
                      Approving...
                    </>
                  ) : (
                    'Approve Token'
                  )}
                </button>
              ) : (
                <button
                  onClick={handleStake}
                  disabled={isStaking || !stakeAmount || parseFloat(stakeAmount) <= 0}
                  className="w-full bg-primary-500 hover:bg-primary-600 disabled:bg-gray-700 disabled:cursor-not-allowed text-white font-medium py-3 rounded-lg transition-colors flex items-center justify-center gap-2"
                >
                  {isStaking ? (
                    <>
                      <Loader2 className="w-4 h-4 animate-spin" />
                      Staking...
                    </>
                  ) : (
                    'Stake'
                  )}
                </button>
              )}
            </div>
          ) : (
            <div className="space-y-4">
              <div>
                <div className="flex justify-between text-sm mb-2">
                  <span className="text-gray-500">Amount</span>
                  <span className="text-gray-400">
                    Staked: {userInfo ? formatTokenAmount(userInfo.stakedAmount) : '0'}
                  </span>
                </div>
                <div className="relative">
                  <input
                    type="number"
                    value={withdrawAmount}
                    onChange={(e) => setWithdrawAmount(e.target.value)}
                    placeholder="0.0"
                    className="w-full bg-dark-300 border border-gray-700 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
                  />
                  <button
                    onClick={() => userInfo && setWithdrawAmount(formatTokenAmount(userInfo.stakedAmount))}
                    className="absolute right-3 top-1/2 -translate-y-1/2 text-primary-400 text-sm hover:text-primary-300"
                  >
                    MAX
                  </button>
                </div>
                {parseFloat(withdrawAmount) > 0 && (
                  <p className="text-gray-500 text-xs mt-1">
                    You will receive: {formatTokenAmount(parseTokenAmount(withdrawAmount) * (10000n - pool.withdrawFee) / 10000n)} (after {withdrawFee}% fee)
                  </p>
                )}
              </div>

              <button
                onClick={handleWithdraw}
                disabled={isWithdrawing || !withdrawAmount || parseFloat(withdrawAmount) <= 0 || isLocked}
                className="w-full bg-primary-500 hover:bg-primary-600 disabled:bg-gray-700 disabled:cursor-not-allowed text-white font-medium py-3 rounded-lg transition-colors flex items-center justify-center gap-2"
              >
                {isWithdrawing ? (
                  <>
                    <Loader2 className="w-4 h-4 animate-spin" />
                    Withdrawing...
                  </>
                ) : isLocked ? (
                  <>
                    <Lock className="w-4 h-4" />
                    Locked
                  </>
                ) : (
                  'Withdraw'
                )}
              </button>

              {/* Emergency Withdraw */}
              {hasStake && isLocked && (
                <button
                  onClick={handleEmergencyWithdraw}
                  disabled={isEmergency}
                  className="w-full bg-red-500/10 hover:bg-red-500/20 border border-red-500/30 text-red-400 font-medium py-3 rounded-lg transition-colors flex items-center justify-center gap-2"
                >
                  {isEmergency ? (
                    <>
                      <Loader2 className="w-4 h-4 animate-spin" />
                      Processing...
                    </>
                  ) : (
                    <>
                      <AlertTriangle className="w-4 h-4" />
                      Emergency Withdraw (10% penalty)
                    </>
                  )}
                </button>
              )}
            </div>
          )}

          {/* Reward Actions */}
          {hasStake && pendingRewards && pendingRewards > 0n && (
            <div className="flex gap-2 mt-4 pt-4 border-t border-gray-800">
              <button
                onClick={handleClaim}
                disabled={isClaiming}
                className="flex-1 bg-secondary-500/10 hover:bg-secondary-500/20 border border-secondary-500/30 text-secondary-400 font-medium py-2 rounded-lg transition-colors flex items-center justify-center gap-2"
              >
                {isClaiming ? (
                  <Loader2 className="w-4 h-4 animate-spin" />
                ) : (
                  'Claim Rewards'
                )}
              </button>
              {pool.stakingToken === pool.rewardToken && (
                <button
                  onClick={handleCompound}
                  disabled={isCompounding}
                  className="flex-1 bg-green-500/10 hover:bg-green-500/20 border border-green-500/30 text-green-400 font-medium py-2 rounded-lg transition-colors flex items-center justify-center gap-2"
                >
                  {isCompounding ? (
                    <Loader2 className="w-4 h-4 animate-spin" />
                  ) : (
                    <>
                      <Zap className="w-4 h-4" />
                      Compound
                    </>
                  )}
                </button>
              )}
            </div>
          )}
        </div>
      ) : (
        <div className="p-6 text-center">
          <p className="text-gray-500">Connect wallet to stake</p>
        </div>
      )}
    </div>
  );
}
