import { createConfig, http } from 'wagmi'
import { mainnet, arbitrum, base, sepolia, hardhat } from 'wagmi/chains'
import { injected, walletConnect } from 'wagmi/connectors'

// Contract addresses - Update these after deployment
export const CONTRACTS = {
  // Mainnet
  [mainnet.id]: {
    staking: '0x...', // Deployed address
    rewardToken: '0x...',
  },
  // Arbitrum
  [arbitrum.id]: {
    staking: '0x...',
    rewardToken: '0x...',
  },
  // Base
  [base.id]: {
    staking: '0x...',
    rewardToken: '0x...',
  },
  // Sepolia Testnet
  [sepolia.id]: {
    staking: '0x...',
    rewardToken: '0x...',
  },
  // Local Hardhat
  [hardhat.id]: {
    staking: '0x5FbDB2315678afecb367f032d93F642f64180aa3',
    rewardToken: '0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512',
  },
} as const;

// Supported chains
export const SUPPORTED_CHAINS = [mainnet, arbitrum, base, sepolia, hardhat] as const;

// Wagmi config
export const config = createConfig({
  chains: SUPPORTED_CHAINS,
  connectors: [
    injected({ target: 'metaMask' }),
    walletConnect({
      projectId: import.meta.env.VITE_WC_PROJECT_ID || 'YOUR_PROJECT_ID',
      showQrModal: true,
    }),
  ],
  transports: {
    [mainnet.id]: http(import.meta.env.VITE_MAINNET_RPC),
    [arbitrum.id]: http(import.meta.env.VITE_ARBITRUM_RPC),
    [base.id]: http(import.meta.env.VITE_BASE_RPC),
    [sepolia.id]: http(import.meta.env.VITE_SEPOLIA_RPC),
    [hardhat.id]: http('http://127.0.0.1:8545'),
  },
});

// Explorer URLs
export const EXPLORERS = {
  [mainnet.id]: 'https://etherscan.io',
  [arbitrum.id]: 'https://arbiscan.io',
  [base.id]: 'https://basescan.org',
  [sepolia.id]: 'https://sepolia.etherscan.io',
  [hardhat.id]: '',
} as const;

// Helper to get contract address for current chain
export function getContractAddress(chainId: number, contract: 'staking' | 'rewardToken'): string {
  const addresses = CONTRACTS[chainId as keyof typeof CONTRACTS];
  if (!addresses) throw new Error(`Unsupported chain: ${chainId}`);
  return addresses[contract];
}

// Format wei to ETH
export function formatAmount(wei: bigint, decimals: number = 18): string {
  const value = Number(wei) / 10 ** decimals;
  return value.toLocaleString('en-US', { 
    maximumFractionDigits: 6,
    minimumFractionDigits: 0,
  });
}

// Parse ETH to wei
export function parseAmount(amount: string, decimals: number = 18): bigint {
  return BigInt(Math.floor(parseFloat(amount) * 10 ** decimals));
}

// Format APY
export function formatAPY(apyBps: bigint): string {
  const apy = Number(apyBps) / 100;
  return `${apy.toFixed(2)}%`;
}

// Format timestamp to date
export function formatUnlockTime(timestamp: bigint): string {
  const date = new Date(Number(timestamp) * 1000);
  const now = new Date();
  
  if (date <= now) {
    return 'Unlocked';
  }
  
  const diffMs = date.getTime() - now.getTime();
  const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));
  const diffHours = Math.floor((diffMs % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
  
  if (diffDays > 0) {
    return `${diffDays}d ${diffHours}h`;
  }
  return `${diffHours}h`;
}
