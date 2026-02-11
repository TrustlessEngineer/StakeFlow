import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt, useChainId } from 'wagmi';
import { parseEther, formatEther } from 'viem';
import { StakeFlowStakingABI, ERC20ABI } from '@/abis/StakeFlowStaking';
import { getContractAddress, formatTokenAmount, parseTokenAmount } from '@/utils/config';
import { useEffect, useState } from 'react';

// Pool data type
export interface Pool {
  id: number;
  stakingToken: string;
  rewardToken: string;
  totalStaked: bigint;
  rewardRate: bigint;
  lockDuration: bigint;
  lastUpdateTime: bigint;
  rewardPerTokenStored: bigint;
  isActive: boolean;
  depositFee: bigint;
  withdrawFee: bigint;
  apy: bigint;
}

// User info type
export interface UserInfo {
  stakedAmount: bigint;
  rewardDebt: bigint;
  pendingRewards: bigint;
  lastStakeTime: bigint;
  unlockTime: bigint;
}

// Hook to get pool count
export function usePoolCount() {
  const chainId = useChainId();
  
  return useReadContract({
    address: getContractAddress(chainId, 'staking') as `0x${string}`,
    abi: StakeFlowStakingABI,
    functionName: 'poolCount',
  });
}

// Hook to get pool data
export function usePool(poolId: number): { data?: Pool; isLoading: boolean; error: Error | null } {
  const chainId = useChainId();
  const [pool, setPool] = useState<Pool | undefined>();
  
  const { data: poolData, isLoading: poolLoading, error: poolError } = useReadContract({
    address: getContractAddress(chainId, 'staking') as `0x${string}`,
    abi: StakeFlowStakingABI,
    functionName: 'getPool',
    args: [BigInt(poolId)],
  });
  
  const { data: apyData, isLoading: apyLoading } = useReadContract({
    address: getContractAddress(chainId, 'staking') as `0x${string}`,
    abi: StakeFlowStakingABI,
    functionName: 'getPoolAPY',
    args: [BigInt(poolId)],
  });
  
  useEffect(() => {
    if (poolData && apyData !== undefined) {
      setPool({
        id: poolId,
        stakingToken: poolData.stakingToken,
        rewardToken: poolData.rewardToken,
        totalStaked: poolData.totalStaked,
        rewardRate: poolData.rewardRate,
        lockDuration: poolData.lockDuration,
        lastUpdateTime: poolData.lastUpdateTime,
        rewardPerTokenStored: poolData.rewardPerTokenStored,
        isActive: poolData.isActive,
        depositFee: poolData.depositFee,
        withdrawFee: poolData.withdrawFee,
        apy: apyData,
      });
    }
  }, [poolData, apyData, poolId]);
  
  return { 
    data: pool, 
    isLoading: poolLoading || apyLoading, 
    error: poolError as Error | null 
  };
}

// Hook to get all pools
export function usePools() {
  const { data: poolCount, isLoading: countLoading } = usePoolCount();
  const [pools, setPools] = useState<Pool[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  
  useEffect(() => {
    if (!poolCount) return;
    
    const fetchPools = async () => {
      setIsLoading(true);
      const poolPromises = [];
      
      for (let i = 0; i < Number(poolCount); i++) {
        // We need to fetch each pool individually
        // In a real app, you might want to batch these or use a subgraph
      }
      
      setIsLoading(false);
    };
    
    fetchPools();
  }, [poolCount]);
  
  return { pools, isLoading: countLoading || isLoading };
}

// Hook to get user info for a pool
export function useUserInfo(poolId: number) {
  const { address } = useAccount();
  const chainId = useChainId();
  
  return useReadContract({
    address: getContractAddress(chainId, 'staking') as `0x${string}`,
    abi: StakeFlowStakingABI,
    functionName: 'getUserInfo',
    args: address ? [BigInt(poolId), address] : undefined,
    query: {
      enabled: !!address,
    },
  });
}

// Hook to get pending rewards
export function usePendingRewards(poolId: number) {
  const { address } = useAccount();
  const chainId = useChainId();
  
  return useReadContract({
    address: getContractAddress(chainId, 'staking') as `0x${string}`,
    abi: StakeFlowStakingABI,
    functionName: 'pendingRewards',
    args: address ? [BigInt(poolId), address] : undefined,
    query: {
      enabled: !!address,
    },
  });
}

// Hook to get token balance
export function useTokenBalance(tokenAddress: string) {
  const { address } = useAccount();
  
  return useReadContract({
    address: tokenAddress as `0x${string}`,
    abi: ERC20ABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    query: {
      enabled: !!address && !!tokenAddress,
    },
  });
}

// Hook to get token allowance
export function useTokenAllowance(tokenAddress: string, spenderAddress: string) {
  const { address } = useAccount();
  
  return useReadContract({
    address: tokenAddress as `0x${string}`,
    abi: ERC20ABI,
    functionName: 'allowance',
    args: address && spenderAddress ? [address, spenderAddress as `0x${string}`] : undefined,
    query: {
      enabled: !!address && !!spenderAddress,
    },
  });
}

// Hook for staking
export function useStake() {
  const chainId = useChainId();
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });
  
  const stake = (poolId: number, amount: string) => {
    writeContract({
      address: getContractAddress(chainId, 'staking') as `0x${string}`,
      abi: StakeFlowStakingABI,
      functionName: 'stake',
      args: [BigInt(poolId), parseTokenAmount(amount)],
    });
  };
  
  return { stake, hash, isPending: isPending || isConfirming, isSuccess, error };
}

// Hook for withdrawing
export function useWithdraw() {
  const chainId = useChainId();
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });
  
  const withdraw = (poolId: number, amount: string) => {
    writeContract({
      address: getContractAddress(chainId, 'staking') as `0x${string}`,
      abi: StakeFlowStakingABI,
      functionName: 'withdraw',
      args: [BigInt(poolId), parseTokenAmount(amount)],
    });
  };
  
  return { withdraw, hash, isPending: isPending || isConfirming, isSuccess, error };
}

// Hook for emergency withdraw
export function useEmergencyWithdraw() {
  const chainId = useChainId();
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });
  
  const emergencyWithdraw = (poolId: number) => {
    writeContract({
      address: getContractAddress(chainId, 'staking') as `0x${string}`,
      abi: StakeFlowStakingABI,
      functionName: 'emergencyWithdraw',
      args: [BigInt(poolId)],
    });
  };
  
  return { emergencyWithdraw, hash, isPending: isPending || isConfirming, isSuccess, error };
}

// Hook for claiming rewards
export function useClaimRewards() {
  const chainId = useChainId();
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });
  
  const claimRewards = (poolId: number) => {
    writeContract({
      address: getContractAddress(chainId, 'staking') as `0x${string}`,
      abi: StakeFlowStakingABI,
      functionName: 'claimRewards',
      args: [BigInt(poolId)],
    });
  };
  
  return { claimRewards, hash, isPending: isPending || isConfirming, isSuccess, error };
}

// Hook for compounding rewards
export function useCompound() {
  const chainId = useChainId();
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });
  
  const compound = (poolId: number) => {
    writeContract({
      address: getContractAddress(chainId, 'staking') as `0x${string}`,
      abi: StakeFlowStakingABI,
      functionName: 'compound',
      args: [BigInt(poolId)],
    });
  };
  
  return { compound, hash, isPending: isPending || isConfirming, isSuccess, error };
}

// Hook for token approval
export function useApproveToken() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });
  
  const approve = (tokenAddress: string, spenderAddress: string, amount: bigint) => {
    writeContract({
      address: tokenAddress as `0x${string}`,
      abi: ERC20ABI,
      functionName: 'approve',
      args: [spenderAddress as `0x${string}`, amount],
    });
  };
  
  return { approve, hash, isPending: isPending || isConfirming, isSuccess, error };
}

// Hook for user positions across all pools
export function useUserPositions() {
  const { address } = useAccount();
  const chainId = useChainId();
  
  return useReadContract({
    address: getContractAddress(chainId, 'staking') as `0x${string}`,
    abi: StakeFlowStakingABI,
    functionName: 'getUserPositions',
    args: address ? [address] : undefined,
    query: {
      enabled: !!address,
    },
  });
}
