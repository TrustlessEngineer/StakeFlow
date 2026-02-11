"""
Blockchain service for interacting with StakeFlow contracts.
"""
import json
import logging
from decimal import Decimal
from typing import Dict, List, Optional, Any, Callable
from dataclasses import dataclass

from web3 import Web3, AsyncWeb3
from web3.contract import Contract
from web3.types import (
    TxReceipt, LogReceipt, BlockData, EventData, FilterParams
)
from eth_typing import ChecksumAddress, HexStr
from eth_abi import decode

from src.core.config import get_settings

logger = logging.getLogger(__name__)

# Contract ABIs
STAKING_CONTRACT_ABI = [
    {
        "inputs": [{"internalType": "uint256", "name": "_poolId", "type": "uint256"}],
        "name": "getPool",
        "outputs": [{
            "components": [
                {"internalType": "address", "name": "stakingToken", "type": "address"},
                {"internalType": "address", "name": "rewardToken", "type": "address"},
                {"internalType": "uint256", "name": "totalStaked", "type": "uint256"},
                {"internalType": "uint256", "name": "rewardRate", "type": "uint256"},
                {"internalType": "uint256", "name": "lockDuration", "type": "uint256"},
                {"internalType": "uint256", "name": "lastUpdateTime", "type": "uint256"},
                {"internalType": "uint256", "name": "rewardPerTokenStored", "type": "uint256"},
                {"internalType": "bool", "name": "isActive", "type": "bool"},
                {"internalType": "uint256", "name": "depositFee", "type": "uint256"},
                {"internalType": "uint256", "name": "withdrawFee", "type": "uint256"}
            ],
            "internalType": "struct IStakeFlowStaking.Pool",
            "name": "",
            "type": "tuple"
        }],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [{"internalType": "uint256", "name": "_poolId", "type": "uint256"}],
        "name": "getPoolAPY",
        "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [],
        "name": "poolCount",
        "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [
            {"internalType": "uint256", "name": "_poolId", "type": "uint256"},
            {"internalType": "address", "name": "_user", "type": "address"}
        ],
        "name": "getUserInfo",
        "outputs": [{
            "components": [
                {"internalType": "uint256", "name": "stakedAmount", "type": "uint256"},
                {"internalType": "uint256", "name": "rewardDebt", "type": "uint256"},
                {"internalType": "uint256", "name": "pendingRewards", "type": "uint256"},
                {"internalType": "uint256", "name": "lastStakeTime", "type": "uint256"},
                {"internalType": "uint256", "name": "unlockTime", "type": "uint256"}
            ],
            "internalType": "struct IStakeFlowStaking.UserInfo",
            "name": "",
            "type": "tuple"
        }],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [
            {"internalType": "uint256", "name": "_poolId", "type": "uint256"},
            {"internalType": "address", "name": "_user", "type": "address"}
        ],
        "name": "pendingRewards",
        "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [{"internalType": "address", "name": "_user", "type": "address"}],
        "name": "getUserPositions",
        "outputs": [
            {"internalType": "uint256[]", "name": "poolIds", "type": "uint256[]"},
            {"internalType": "uint256[]", "name": "stakes", "type": "uint256[]"},
            {"internalType": "uint256[]", "name": "rewards", "type": "uint256[]"}
        ],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "anonymous": False,
        "inputs": [
            {"indexed": True, "name": "user", "type": "address"},
            {"indexed": True, "name": "poolId", "type": "uint256"},
            {"indexed": False, "name": "amount", "type": "uint256"},
            {"indexed": False, "name": "timestamp", "type": "uint256"}
        ],
        "name": "Staked",
        "type": "event"
    },
    {
        "anonymous": False,
        "inputs": [
            {"indexed": True, "name": "user", "type": "address"},
            {"indexed": True, "name": "poolId", "type": "uint256"},
            {"indexed": False, "name": "amount", "type": "uint256"},
            {"indexed": False, "name": "rewardAmount", "type": "uint256"},
            {"indexed": False, "name": "timestamp", "type": "uint256"}
        ],
        "name": "Withdrawn",
        "type": "event"
    },
    {
        "anonymous": False,
        "inputs": [
            {"indexed": True, "name": "user", "type": "address"},
            {"indexed": True, "name": "poolId", "type": "uint256"},
            {"indexed": False, "name": "rewardAmount", "type": "uint256"},
            {"indexed": False, "name": "timestamp", "type": "uint256"}
        ],
        "name": "RewardClaimed",
        "type": "event"
    },
    {
        "anonymous": False,
        "inputs": [
            {"indexed": True, "name": "user", "type": "address"},
            {"indexed": True, "name": "poolId", "type": "uint256"},
            {"indexed": False, "name": "amount", "type": "uint256"},
            {"indexed": False, "name": "penalty", "type": "uint256"}
        ],
        "name": "EmergencyWithdrawn",
        "type": "event"
    }
]

ERC20_ABI = [
    {
        "constant": True,
        "inputs": [{"name": "_owner", "type": "address"}],
        "name": "balanceOf",
        "outputs": [{"name": "balance", "type": "uint256"}],
        "type": "function"
    },
    {
        "constant": True,
        "inputs": [],
        "name": "decimals",
        "outputs": [{"name": "", "type": "uint8"}],
        "type": "function"
    },
    {
        "constant": True,
        "inputs": [],
        "name": "symbol",
        "outputs": [{"name": "", "type": "string"}],
        "type": "function"
    },
    {
        "constant": True,
        "inputs": [],
        "name": "totalSupply",
        "outputs": [{"name": "", "type": "uint256"}],
        "type": "function"
    }
]


@dataclass
class PoolInfo:
    """Pool information data class."""
    pool_id: int
    staking_token: str
    reward_token: str
    total_staked: Decimal
    reward_rate: Decimal
    lock_duration: int
    is_active: bool
    deposit_fee: int
    withdraw_fee: int
    apy: Decimal


@dataclass
class UserStakeInfo:
    """User stake information data class."""
    staked_amount: Decimal
    reward_debt: Decimal
    pending_rewards: Decimal
    last_stake_time: int
    unlock_time: int


class BlockchainService:
    """Service for blockchain interactions."""
    
    def __init__(self, chain: str = "sepolia"):
        """Initialize blockchain service for a specific chain."""
        self.settings = get_settings()
        self.chain = chain.lower()
        self.config = self.settings.get_chain_config(chain)
        
        # Initialize Web3
        self.w3 = Web3(Web3.HTTPProvider(self.config["rpc_url"]))
        if not self.w3.is_connected():
            raise ConnectionError(f"Failed to connect to {chain} RPC")
        
        # Initialize contracts
        self.staking_contract: Contract = self.w3.eth.contract(
            address=Web3.to_checksum_address(self.config["staking_contract"]),
            abi=STAKING_CONTRACT_ABI
        )
        
        # Cache for token contracts
        self._token_contracts: Dict[str, Contract] = {}
        
        logger.info(f"Blockchain service initialized for {chain}")
    
    def get_token_contract(self, token_address: str) -> Contract:
        """Get or create token contract instance."""
        if token_address not in self._token_contracts:
            self._token_contracts[token_address] = self.w3.eth.contract(
                address=Web3.to_checksum_address(token_address),
                abi=ERC20_ABI
            )
        return self._token_contracts[token_address]
    
    def get_block_number(self) -> int:
        """Get current block number."""
        return self.w3.eth.block_number
    
    def get_block(self, block_number: int) -> BlockData:
        """Get block by number."""
        return self.w3.eth.get_block(block_number, full_transactions=False)
    
    def get_pool_count(self) -> int:
        """Get total number of pools."""
        try:
            return self.staking_contract.functions.poolCount().call()
        except Exception as e:
            logger.error(f"Error getting pool count: {e}")
            return 0
    
    def get_pool_info(self, pool_id: int) -> Optional[PoolInfo]:
        """Get pool information."""
        try:
            pool_data = self.staking_contract.functions.getPool(pool_id).call()
            apy = self.staking_contract.functions.getPoolAPY(pool_id).call()
            
            return PoolInfo(
                pool_id=pool_id,
                staking_token=pool_data[0],
                reward_token=pool_data[1],
                total_staked=Decimal(pool_data[2]),
                reward_rate=Decimal(pool_data[3]),
                lock_duration=pool_data[4],
                is_active=pool_data[7],
                deposit_fee=pool_data[8],
                withdraw_fee=pool_data[9],
                apy=Decimal(apy)
            )
        except Exception as e:
            logger.error(f"Error getting pool {pool_id} info: {e}")
            return None
    
    def get_user_info(self, pool_id: int, user_address: str) -> Optional[UserStakeInfo]:
        """Get user stake information for a pool."""
        try:
            user_data = self.staking_contract.functions.getUserInfo(
                pool_id, 
                Web3.to_checksum_address(user_address)
            ).call()
            
            pending = self.staking_contract.functions.pendingRewards(
                pool_id,
                Web3.to_checksum_address(user_address)
            ).call()
            
            return UserStakeInfo(
                staked_amount=Decimal(user_data[0]),
                reward_debt=Decimal(user_data[1]),
                pending_rewards=Decimal(pending),
                last_stake_time=user_data[3],
                unlock_time=user_data[4]
            )
        except Exception as e:
            logger.error(f"Error getting user info: {e}")
            return None
    
    def get_user_positions(self, user_address: str) -> Dict[str, List]:
        """Get all user positions across pools."""
        try:
            positions = self.staking_contract.functions.getUserPositions(
                Web3.to_checksum_address(user_address)
            ).call()
            
            return {
                "pool_ids": [int(x) for x in positions[0]],
                "stakes": [Decimal(x) for x in positions[1]],
                "rewards": [Decimal(x) for x in positions[2]]
            }
        except Exception as e:
            logger.error(f"Error getting user positions: {e}")
            return {"pool_ids": [], "stakes": [], "rewards": []}
    
    def get_token_balance(self, token_address: str, wallet_address: str) -> Decimal:
        """Get ERC20 token balance."""
        try:
            token = self.get_token_contract(token_address)
            balance = token.functions.balanceOf(
                Web3.to_checksum_address(wallet_address)
            ).call()
            decimals = token.functions.decimals().call()
            return Decimal(balance) / Decimal(10 ** decimals)
        except Exception as e:
            logger.error(f"Error getting token balance: {e}")
            return Decimal(0)
    
    def get_events(
        self,
        event_name: str,
        from_block: int,
        to_block: int,
        argument_filters: Optional[Dict] = None
    ) -> List[EventData]:
        """Get contract events."""
        try:
            event = getattr(self.staking_contract.events, event_name)
            filter_params = {"fromBlock": from_block, "toBlock": to_block}
            
            if argument_filters:
                filter_params["argument_filters"] = argument_filters
            
            return event().get_logs(**filter_params)
        except Exception as e:
            logger.error(f"Error getting events: {e}")
            return []
    
    def get_all_events(
        self,
        from_block: int,
        to_block: int
    ) -> List[EventData]:
        """Get all staking contract events."""
        events = []
        event_names = ["Staked", "Withdrawn", "RewardClaimed", "EmergencyWithdrawn"]
        
        for event_name in event_names:
            try:
                event_logs = self.get_events(event_name, from_block, to_block)
                events.extend(event_logs)
            except Exception as e:
                logger.warning(f"Error getting {event_name} events: {e}")
        
        # Sort by block number and log index
        events.sort(key=lambda x: (x["blockNumber"], x["logIndex"]))
        return events
    
    def estimate_gas_price(self) -> int:
        """Get current gas price."""
        try:
            return self.w3.eth.gas_price
        except Exception as e:
            logger.error(f"Error estimating gas price: {e}")
            return 0
    
    def get_transaction_receipt(self, tx_hash: str) -> Optional[TxReceipt]:
        """Get transaction receipt."""
        try:
            return self.w3.eth.get_transaction_receipt(tx_hash)
        except Exception as e:
            logger.error(f"Error getting transaction receipt: {e}")
            return None


# Factory for blockchain services
_blockchain_services: Dict[str, BlockchainService] = {}


def get_blockchain_service(chain: str = "sepolia") -> BlockchainService:
    """Get or create blockchain service for a chain."""
    chain = chain.lower()
    if chain not in _blockchain_services:
        _blockchain_services[chain] = BlockchainService(chain)
    return _blockchain_services[chain]


def get_all_services() -> Dict[str, BlockchainService]:
    """Get all initialized blockchain services."""
    return _blockchain_services.copy()
