import { useAccount } from 'wagmi';
import { Wallet, TrendingUp, Clock, ArrowUpRight } from 'lucide-react';
import { useUserPositions, usePool } from '@/hooks/useStaking';
import { formatTokenAmount, formatUnlockTime } from '@/utils/config';
import { truncateAddress } from '@/utils/format';

export function Portfolio() {
  const { address, isConnected } = useAccount();
  const { data: positions } = useUserPositions();

  if (!isConnected) {
    return (
      <div className="text-center py-20">
        <div className="w-20 h-20 bg-primary-500/10 rounded-full flex items-center justify-center mx-auto mb-6">
          <Wallet className="w-10 h-10 text-primary-500" />
        </div>
        <h2 className="text-2xl font-bold mb-2">Connect Your Wallet</h2>
        <p className="text-gray-500">
          Connect your wallet to view your staking portfolio
        </p>
      </div>
    );
  }

  const hasPositions = positions && positions[0].length > 0;

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-3xl font-bold">Your Portfolio</h1>
        <p className="text-gray-400 mt-1">
          Wallet: {truncateAddress(address || '')}
        </p>
      </div>

      {/* Stats Overview */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="bg-dark-200 border border-gray-800 rounded-xl p-6">
          <div className="flex items-center gap-3 mb-4">
            <div className="p-2 bg-primary-500/10 rounded-lg">
              <Wallet className="w-5 h-5 text-primary-400" />
            </div>
            <span className="text-gray-400">Total Staked</span>
          </div>
          <p className="text-2xl font-bold">
            {hasPositions 
              ? formatTokenAmount(
                  positions[1].reduce((acc: bigint, val: bigint) => acc + val, 0n)
                )
              : '0'}
          </p>
        </div>

        <div className="bg-dark-200 border border-gray-800 rounded-xl p-6">
          <div className="flex items-center gap-3 mb-4">
            <div className="p-2 bg-green-500/10 rounded-lg">
              <TrendingUp className="w-5 h-5 text-green-400" />
            </div>
            <span className="text-gray-400">Total Rewards</span>
          </div>
          <p className="text-2xl font-bold text-green-400">
            {hasPositions
              ? formatTokenAmount(
                  positions[2].reduce((acc: bigint, val: bigint) => acc + val, 0n)
                )
              : '0'}
          </p>
        </div>

        <div className="bg-dark-200 border border-gray-800 rounded-xl p-6">
          <div className="flex items-center gap-3 mb-4">
            <div className="p-2 bg-secondary-500/10 rounded-lg">
              <Clock className="w-5 h-5 text-secondary-400" />
            </div>
            <span className="text-gray-400">Active Positions</span>
          </div>
          <p className="text-2xl font-bold">
            {positions ? positions[0].length : 0}
          </p>
        </div>
      </div>

      {/* Positions Table */}
      <div className="bg-dark-200 border border-gray-800 rounded-xl overflow-hidden">
        <div className="px-6 py-4 border-b border-gray-800">
          <h2 className="text-lg font-semibold">Active Positions</h2>
        </div>

        {!hasPositions ? (
          <div className="text-center py-12">
            <p className="text-gray-500">No active positions</p>
            <p className="text-gray-600 text-sm mt-1">
              Start staking in pools to see your positions here
            </p>
            <a
              href="/pools"
              className="inline-flex items-center gap-2 mt-4 text-primary-400 hover:text-primary-300"
            >
              View Pools
              <ArrowUpRight className="w-4 h-4" />
            </a>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="text-left text-gray-500 text-sm">
                  <th className="px-6 py-3 font-medium">Pool</th>
                  <th className="px-6 py-3 font-medium">Staked Amount</th>
                  <th className="px-6 py-3 font-medium">Pending Rewards</th>
                  <th className="px-6 py-3 font-medium">Unlock Status</th>
                  <th className="px-6 py-3 font-medium">Action</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-800">
                {positions[0].map((poolId: bigint, i: number) => (
                  <PositionRow
                    key={i}
                    poolId={Number(poolId)}
                    stakedAmount={positions[1][i]}
                    pendingRewards={positions[2][i]}
                  />
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}

// Position row component
import { useUserInfo } from '@/hooks/useStaking';
import { Unlock, Lock } from 'lucide-react';

function PositionRow({
  poolId,
  stakedAmount,
  pendingRewards,
}: {
  poolId: number;
  stakedAmount: bigint;
  pendingRewards: bigint;
}) {
  const { data: pool } = usePool(poolId);
  const { data: userInfo } = useUserInfo(poolId);

  const isUnlocked = userInfo && userInfo.unlockTime <= BigInt(Math.floor(Date.now() / 1000));

  return (
    <tr className="hover:bg-dark-300/50">
      <td className="px-6 py-4">
        <div className="flex items-center gap-3">
          <div className="w-8 h-8 bg-gradient-to-br from-primary-500 to-secondary-500 rounded-lg flex items-center justify-center">
            <span className="text-white text-xs font-bold">{poolId}</span>
          </div>
          <span className="font-medium">Pool #{poolId}</span>
        </div>
      </td>
      <td className="px-6 py-4">
        <span className="font-medium">{formatTokenAmount(stakedAmount)}</span>
        <span className="text-gray-500 text-sm ml-1">tokens</span>
      </td>
      <td className="px-6 py-4">
        <span className="text-green-400 font-medium">
          +{formatTokenAmount(pendingRewards)}
        </span>
      </td>
      <td className="px-6 py-4">
        {isUnlocked ? (
          <span className="inline-flex items-center gap-1 text-green-400 text-sm">
            <Unlock className="w-4 h-4" />
            Unlocked
          </span>
        ) : (
          <span className="inline-flex items-center gap-1 text-orange-400 text-sm">
            <Lock className="w-4 h-4" />
            {userInfo && formatUnlockTime(userInfo.unlockTime)}
          </span>
        )}
      </td>
      <td className="px-6 py-4">
        <a
          href="/pools"
          className="text-primary-400 hover:text-primary-300 text-sm font-medium"
        >
          Manage →
        </a>
      </td>
    </tr>
  );
}
