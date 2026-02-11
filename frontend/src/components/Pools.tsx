import { useState, useEffect } from 'react';
import { usePoolCount } from '@/hooks/useStaking';
import { PoolCard } from './PoolCard';
import { useUserInfo } from '@/hooks/useStaking';
import { Loader2, Plus } from 'lucide-react';

export function Pools() {
  const { data: poolCount, isLoading, refetch: refetchCount } = usePoolCount();
  const [selectedPool, setSelectedPool] = useState<number | null>(null);

  // Generate pool IDs
  const poolIds = poolCount ? Array.from({ length: Number(poolCount) }, (_, i) => i) : [];

  const handleSuccess = () => {
    // Refetch data after successful transaction
    refetchCount();
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold">Staking Pools</h1>
          <p className="text-gray-400 mt-1">
            Choose a pool to stake your tokens and start earning rewards
          </p>
        </div>
        <button className="flex items-center gap-2 bg-primary-500 hover:bg-primary-600 text-white px-4 py-2 rounded-lg transition-colors">
          <Plus className="w-4 h-4" />
          Create Pool
        </button>
      </div>

      {/* Pool Grid */}
      {isLoading ? (
        <div className="flex items-center justify-center py-20">
          <Loader2 className="w-8 h-8 animate-spin text-primary-500" />
        </div>
      ) : poolIds.length === 0 ? (
        <div className="text-center py-20 bg-dark-200 border border-gray-800 rounded-xl">
          <p className="text-gray-500 text-lg">No pools available yet</p>
          <p className="text-gray-600 text-sm mt-2">
            Check back later or create a new pool
          </p>
        </div>
      ) : (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {poolIds.map((poolId) => (
            <PoolItem 
              key={poolId} 
              poolId={poolId} 
              onSuccess={handleSuccess}
            />
          ))}
        </div>
      )}
    </div>
  );
}

// Separate component to fetch individual pool data
import { usePool } from '@/hooks/useStaking';

function PoolItem({ poolId, onSuccess }: { poolId: number; onSuccess: () => void }) {
  const { data: pool, isLoading } = usePool(poolId);
  const { data: userInfo } = useUserInfo(poolId);

  if (isLoading || !pool) {
    return (
      <div className="bg-dark-200 border border-gray-800 rounded-xl p-6 animate-pulse">
        <div className="h-32 bg-dark-300 rounded-lg" />
      </div>
    );
  }

  return (
    <PoolCard 
      pool={pool} 
      userInfo={userInfo} 
      onSuccess={onSuccess}
    />
  );
}
