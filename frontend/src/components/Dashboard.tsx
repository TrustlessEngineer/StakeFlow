import { useAccount } from 'wagmi';
import { TrendingUp, Users, DollarSign, Activity } from 'lucide-react';
import { formatCompact, formatTokenAmount } from '@/utils/format';
import { usePoolCount, useUserPositions } from '@/hooks/useStaking';

export function Dashboard() {
  const { isConnected } = useAccount();
  const { data: poolCount } = usePoolCount();
  const { data: userPositions } = useUserPositions();

  // Calculate total staked across all pools (mock for now)
  const totalStaked = 12500000; // Mock value
  const totalUsers = 3420; // Mock value
  const avgAPY = 12.5; // Mock value

  const stats = [
    {
      label: 'Total Value Locked',
      value: `$${formatCompact(totalStaked)}`,
      change: '+12.5%',
      icon: DollarSign,
      color: 'text-green-400',
      bgColor: 'bg-green-500/10',
    },
    {
      label: 'Active Pools',
      value: poolCount?.toString() || '0',
      change: '+2 new',
      icon: Activity,
      color: 'text-primary-400',
      bgColor: 'bg-primary-500/10',
    },
    {
      label: 'Total Users',
      value: formatCompact(totalUsers),
      change: '+8.2%',
      icon: Users,
      color: 'text-secondary-400',
      bgColor: 'bg-secondary-500/10',
    },
    {
      label: 'Average APY',
      value: `${avgAPY}%`,
      change: '+1.2%',
      icon: TrendingUp,
      color: 'text-orange-400',
      bgColor: 'bg-orange-500/10',
    },
  ];

  return (
    <div className="space-y-8">
      {/* Hero Section */}
      <div className="relative overflow-hidden rounded-2xl bg-gradient-to-br from-primary-600/20 via-dark-200 to-secondary-600/20 border border-gray-800 p-8">
        <div className="absolute inset-0 bg-[url('data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNjAiIGhlaWdodD0iNjAiIHZpZXdCb3g9IjAgMCA2MCA2MCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48ZyBmaWxsPSJub25lIiBmaWxsLXJ1bGU9ImV2ZW5vZGQiPjxnIGZpbGw9IiMzYjgyZjYiIGZpbGwtb3BhY2l0eT0iMC4wNSI+PGNpcmNsZSBjeD0iMzAiIGN5PSIzMCIgcj0iMiIvPjwvZz48L2c+PC9zdmc+')] opacity-30" />
        
        <div className="relative">
          <h1 className="text-4xl font-bold mb-4">
            <span className="bg-gradient-to-r from-primary-400 via-secondary-400 to-primary-400 bg-clip-text text-transparent animate-gradient">
              StakeFlow
            </span>
          </h1>
          <p className="text-gray-400 text-lg max-w-2xl mb-6">
            Maximize your crypto yields with our secure, gas-optimized staking protocol. 
            Earn rewards across multiple pools with automatic compounding.
          </p>
          
          {!isConnected && (
            <div className="inline-flex items-center gap-2 px-4 py-2 bg-primary-500/10 border border-primary-500/20 rounded-lg text-primary-400 text-sm">
              <span className="w-2 h-2 bg-primary-500 rounded-full animate-pulse" />
              Connect your wallet to start staking
            </div>
          )}
        </div>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        {stats.map((stat) => (
          <div
            key={stat.label}
            className="bg-dark-200 border border-gray-800 rounded-xl p-6 hover:border-gray-700 transition-colors"
          >
            <div className="flex items-start justify-between">
              <div>
                <p className="text-gray-400 text-sm">{stat.label}</p>
                <p className="text-2xl font-bold mt-1">{stat.value}</p>
                <p className="text-green-400 text-sm mt-1">{stat.change}</p>
              </div>
              <div className={`p-3 rounded-lg ${stat.bgColor}`}>
                <stat.icon className={`w-5 h-5 ${stat.color}`} />
              </div>
            </div>
          </div>
        ))}
      </div>

      {/* Quick Actions */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Featured Pools */}
        <div className="bg-dark-200 border border-gray-800 rounded-xl p-6">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-lg font-semibold">Featured Pools</h2>
            <a href="/pools" className="text-primary-400 text-sm hover:text-primary-300">
              View All →
            </a>
          </div>
          <div className="space-y-3">
            {[
              { name: 'ETH Staking', apy: '8.5%', tvl: '$5.2M', lock: '7 days' },
              { name: 'USDC Stable', apy: '12.3%', tvl: '$3.1M', lock: '30 days' },
              { name: 'SFT Rewards', apy: '25.7%', tvl: '$1.8M', lock: '90 days' },
            ].map((pool) => (
              <div
                key={pool.name}
                className="flex items-center justify-between p-4 bg-dark-300 rounded-lg hover:bg-gray-800/50 transition-colors"
              >
                <div>
                  <p className="font-medium">{pool.name}</p>
                  <p className="text-gray-500 text-sm">Lock: {pool.lock}</p>
                </div>
                <div className="text-right">
                  <p className="text-green-400 font-medium">{pool.apy} APY</p>
                  <p className="text-gray-500 text-sm">{pool.tvl} TVL</p>
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* User Overview */}
        {isConnected ? (
          <div className="bg-dark-200 border border-gray-800 rounded-xl p-6">
            <h2 className="text-lg font-semibold mb-4">Your Portfolio</h2>
            {userPositions && userPositions[0].length > 0 ? (
              <div className="space-y-3">
                {userPositions[0].map((poolId: bigint, i: number) => (
                  <div
                    key={i}
                    className="flex items-center justify-between p-4 bg-dark-300 rounded-lg"
                  >
                    <div>
                      <p className="font-medium">Pool #{poolId.toString()}</p>
                      <p className="text-gray-500 text-sm">
                        Staked: {formatTokenAmount(userPositions[1][i])}
                      </p>
                    </div>
                    <div className="text-right">
                      <p className="text-primary-400">
                        +{formatTokenAmount(userPositions[2][i])}
                      </p>
                      <p className="text-gray-500 text-sm">rewards</p>
                    </div>
                  </div>
                ))}
              </div>
            ) : (
              <div className="text-center py-8 text-gray-500">
                <p>No active positions</p>
                <p className="text-sm mt-1">Start staking to see your portfolio</p>
              </div>
            )}
          </div>
        ) : (
          <div className="bg-dark-200 border border-gray-800 rounded-xl p-6 flex flex-col items-center justify-center text-center">
            <div className="w-16 h-16 bg-primary-500/10 rounded-full flex items-center justify-center mb-4">
              <TrendingUp className="w-8 h-8 text-primary-500" />
            </div>
            <h2 className="text-lg font-semibold mb-2">Connect Wallet</h2>
            <p className="text-gray-500 mb-4">
              Connect your wallet to view your portfolio and start earning rewards
            </p>
          </div>
        )}
      </div>
    </div>
  );
}
