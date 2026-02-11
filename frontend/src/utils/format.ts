/**
 * Format a number with commas and specified decimals
 */
export function formatNumber(num: number | string, decimals = 4): string {
  const value = typeof num === 'string' ? parseFloat(num) : num;
  if (isNaN(value)) return '0';
  
  return value.toLocaleString('en-US', {
    maximumFractionDigits: decimals,
    minimumFractionDigits: 0,
  });
}

/**
 * Format a percentage value
 */
export function formatPercent(value: number | string, decimals = 2): string {
  const num = typeof value === 'string' ? parseFloat(value) : value;
  if (isNaN(num)) return '0%';
  return `${num.toFixed(decimals)}%`;
}

/**
 * Format token amount from wei
 */
export function formatTokenAmount(
  amount: bigint | string,
  decimals = 18,
  displayDecimals = 4
): string {
  if (typeof amount === 'string') {
    amount = BigInt(amount);
  }
  
  const value = Number(amount) / 10 ** decimals;
  
  if (value === 0) return '0';
  if (value < 0.0001) return '< 0.0001';
  
  return value.toLocaleString('en-US', {
    maximumFractionDigits: displayDecimals,
    minimumFractionDigits: 0,
  });
}

/**
 * Parse token amount to wei
 */
export function parseTokenAmount(amount: string, decimals = 18): bigint {
  const value = parseFloat(amount);
  if (isNaN(value) || value < 0) return 0n;
  
  return BigInt(Math.floor(value * 10 ** decimals));
}

/**
 * Truncate address for display
 */
export function truncateAddress(address: string, start = 6, end = 4): string {
  if (!address) return '';
  if (address.length < start + end + 3) return address;
  return `${address.slice(0, start)}...${address.slice(-end)}`;
}

/**
 * Format time duration in seconds to human readable
 */
export function formatDuration(seconds: number): string {
  if (seconds < 60) return `${seconds}s`;
  if (seconds < 3600) return `${Math.floor(seconds / 60)}m`;
  if (seconds < 86400) return `${Math.floor(seconds / 3600)}h`;
  if (seconds < 604800) return `${Math.floor(seconds / 86400)}d`;
  if (seconds < 2628000) return `${Math.floor(seconds / 604800)}w`;
  return `${Math.floor(seconds / 2628000)}mo`;
}

/**
 * Format timestamp to relative time
 */
export function timeAgo(timestamp: number): string {
  const seconds = Math.floor((Date.now() - timestamp * 1000) / 1000);
  
  if (seconds < 60) return 'just now';
  if (seconds < 3600) return `${Math.floor(seconds / 60)}m ago`;
  if (seconds < 86400) return `${Math.floor(seconds / 3600)}h ago`;
  if (seconds < 604800) return `${Math.floor(seconds / 86400)}d ago`;
  return new Date(timestamp * 1000).toLocaleDateString();
}

/**
 * Format USD value with $ sign
 */
export function formatUSD(value: number | string, decimals = 2): string {
  const num = typeof value === 'string' ? parseFloat(value) : value;
  if (isNaN(num)) return '$0.00';
  
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD',
    minimumFractionDigits: decimals,
    maximumFractionDigits: decimals,
  }).format(num);
}

/**
 * Format compact number (e.g., 1.2K, 3.4M)
 */
export function formatCompact(num: number): string {
  if (num < 1000) return num.toString();
  if (num < 1000000) return `${(num / 1000).toFixed(1)}K`;
  if (num < 1000000000) return `${(num / 1000000).toFixed(1)}M`;
  return `${(num / 1000000000).toFixed(1)}B`;
}
