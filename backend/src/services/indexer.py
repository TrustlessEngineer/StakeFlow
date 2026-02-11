"""
Blockchain indexer service for StakeFlow events.
"""
import asyncio
import logging
from datetime import datetime, timedelta
from typing import Optional

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update
from tenacity import retry, stop_after_attempt, wait_exponential

from src.services.blockchain import get_blockchain_service
from src.models.database import (
    Block, Pool, Stake, StakingEvent, DailyStats, IndexerState
)

logger = logging.getLogger(__name__)


class IndexerService:
    """Service for indexing blockchain events."""
    
    def __init__(self, chain: str, db_session: AsyncSession):
        self.chain = chain.lower()
        self.db = db_session
        self.blockchain = get_blockchain_service(chain)
        self.is_running = False
        self._stop_event = asyncio.Event()
    
    async def initialize(self):
        """Initialize indexer state."""
        result = await self.db.execute(
            select(IndexerState).where(IndexerState.chain == self.chain)
        )
        state = result.scalar_one_or_none()
        
        if not state:
            from src.core.config import get_settings
            settings = get_settings()
            
            state = IndexerState(
                chain=self.chain,
                last_block_number=settings.INDEX_START_BLOCK
            )
            self.db.add(state)
            await self.db.commit()
            logger.info(f"Initialized indexer for {self.chain} at block {settings.INDEX_START_BLOCK}")
    
    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=4, max=10)
    )
    async def index_block_range(self, from_block: int, to_block: int):
        """Index events for a range of blocks."""
        logger.info(f"Indexing {self.chain} blocks {from_block} to {to_block}")
        
        try:
            # Get events
            events = self.blockchain.get_all_events(from_block, to_block)
            
            for event in events:
                await self._process_event(event)
            
            # Update indexer state
            await self.db.execute(
                update(IndexerState)
                .where(IndexerState.chain == self.chain)
                .values(
                    last_block_number=to_block,
                    is_syncing=False,
                    updated_at=datetime.utcnow()
                )
            )
            
            await self.db.commit()
            logger.info(f"Indexed {len(events)} events from blocks {from_block}-{to_block}")
            
        except Exception as e:
            logger.error(f"Error indexing blocks: {e}")
            await self.db.rollback()
            raise
    
    async def _process_event(self, event):
        """Process a single event."""
        event_name = event.event
        args = event.args
        tx_hash = event.transactionHash.hex()
        block_number = event.blockNumber
        log_index = event.logIndex
        
        # Get block timestamp
        try:
            block = self.blockchain.get_block(block_number)
            timestamp = datetime.fromtimestamp(block.timestamp)
        except:
            timestamp = datetime.utcnow()
        
        # Create event record
        staking_event = StakingEvent(
            chain=self.chain,
            event_type=event_name,
            tx_hash=tx_hash,
            block_number=block_number,
            log_index=log_index,
            pool_id=args.poolId,
            user_address=args.user.lower(),
            amount=str(args.amount) if hasattr(args, 'amount') else None,
            reward_amount=str(args.rewardAmount) if hasattr(args, 'rewardAmount') else None,
            timestamp=timestamp
        )
        self.db.add(staking_event)
        
        # Update user stake based on event type
        if event_name == "Staked":
            await self._handle_stake(args.poolId, args.user.lower(), args.amount, timestamp)
        elif event_name == "Withdrawn":
            await self._handle_withdraw(args.poolId, args.user.lower(), args.amount, timestamp)
        elif event_name == "EmergencyWithdrawn":
            await self._handle_emergency_withdraw(args.poolId, args.user.lower(), args.amount)
        elif event_name == "RewardClaimed":
            await self._handle_reward_claimed(args.poolId, args.user.lower())
    
    async def _handle_stake(self, pool_id: int, user: str, amount: int, timestamp: datetime):
        """Handle Staked event."""
        result = await self.db.execute(
            select(Stake).where(
                Stake.chain == self.chain,
                Stake.pool_id == pool_id,
                Stake.user_address == user
            )
        )
        stake = result.scalar_one_or_none()
        
        # Get pool for lock duration
        pool_result = await self.db.execute(
            select(Pool).where(Pool.chain == self.chain, Pool.pool_id == pool_id)
        )
        pool = pool_result.scalar_one_or_none()
        lock_duration = timedelta(seconds=pool.lock_duration) if pool else timedelta(days=7)
        
        if stake:
            stake.staked_amount = str(int(stake.staked_amount) + amount)
            stake.last_stake_time = timestamp
            stake.unlock_time = timestamp + lock_duration
            stake.is_active = True
        else:
            # Get or create pool reference
            pool_ref_result = await self.db.execute(
                select(Pool.id).where(Pool.chain == self.chain, Pool.pool_id == pool_id)
            )
            pool_ref_id = pool_ref_result.scalar()
            
            if pool_ref_id:
                stake = Stake(
                    chain=self.chain,
                    pool_id=pool_ref_id,
                    user_address=user,
                    staked_amount=str(amount),
                    last_stake_time=timestamp,
                    unlock_time=timestamp + lock_duration,
                    is_active=True
                )
                self.db.add(stake)
    
    async def _handle_withdraw(self, pool_id: int, user: str, amount: int, timestamp: datetime):
        """Handle Withdrawn event."""
        result = await self.db.execute(
            select(Stake).where(
                Stake.chain == self.chain,
                Stake.pool_id == pool_id,
                Stake.user_address == user
            )
        )
        stake = result.scalar_one_or_none()
        
        if stake:
            new_amount = int(stake.staked_amount) - amount
            if new_amount <= 0:
                stake.staked_amount = "0"
                stake.pending_rewards = "0"
                stake.is_active = False
            else:
                stake.staked_amount = str(new_amount)
                stake.pending_rewards = "0"
    
    async def _handle_emergency_withdraw(self, pool_id: int, user: str, amount: int):
        """Handle EmergencyWithdrawn event."""
        result = await self.db.execute(
            select(Stake).where(
                Stake.chain == self.chain,
                Stake.pool_id == pool_id,
                Stake.user_address == user
            )
        )
        stake = result.scalar_one_or_none()
        
        if stake:
            stake.staked_amount = "0"
            stake.pending_rewards = "0"
            stake.is_active = False
    
    async def _handle_reward_claimed(self, pool_id: int, user: str):
        """Handle RewardClaimed event."""
        result = await self.db.execute(
            select(Stake).where(
                Stake.chain == self.chain,
                Stake.pool_id == pool_id,
                Stake.user_address == user
            )
        )
        stake = result.scalar_one_or_none()
        
        if stake:
            stake.pending_rewards = "0"
    
    async def sync_pools(self):
        """Sync pool information from blockchain."""
        pool_count = self.blockchain.get_pool_count()
        
        for pool_id in range(pool_count):
            pool_info = self.blockchain.get_pool_info(pool_id)
            if not pool_info:
                continue
            
            result = await self.db.execute(
                select(Pool).where(
                    Pool.chain == self.chain,
                    Pool.pool_id == pool_id
                )
            )
            pool = result.scalar_one_or_none()
            
            if pool:
                # Update existing
                pool.staking_token = pool_info.staking_token
                pool.reward_token = pool_info.reward_token
                pool.reward_rate = str(pool_info.reward_rate)
                pool.lock_duration = pool_info.lock_duration
                pool.deposit_fee = pool_info.deposit_fee
                pool.withdraw_fee = pool_info.withdraw_fee
                pool.is_active = pool_info.is_active
            else:
                # Create new
                pool = Pool(
                    chain=self.chain,
                    pool_id=pool_id,
                    staking_token=pool_info.staking_token,
                    reward_token=pool_info.reward_token,
                    reward_rate=str(pool_info.reward_rate),
                    lock_duration=pool_info.lock_duration,
                    deposit_fee=pool_info.deposit_fee,
                    withdraw_fee=pool_info.withdraw_fee,
                    is_active=pool_info.is_active
                )
                self.db.add(pool)
        
        await self.db.commit()
        logger.info(f"Synced {pool_count} pools for {self.chain}")
    
    async def run(self):
        """Main indexer loop."""
        self.is_running = True
        await self.initialize()
        
        from src.core.config import get_settings
        settings = get_settings()
        
        while not self._stop_event.is_set():
            try:
                # Get current state
                result = await self.db.execute(
                    select(IndexerState).where(IndexerState.chain == self.chain)
                )
                state = result.scalar_one()
                
                current_block = self.blockchain.get_block_number()
                last_block = state.last_block_number
                
                if current_block > last_block:
                    # Sync pools first
                    await self.sync_pools()
                    
                    # Calculate batch
                    to_block = min(
                        current_block - 1,  # Leave 1 block buffer
                        last_block + settings.INDEXER_BATCH_SIZE
                    )
                    
                    await self.index_block_range(last_block + 1, to_block)
                
                # Wait before next poll
                await asyncio.wait_for(
                    self._stop_event.wait(),
                    timeout=settings.INDEXER_POLL_INTERVAL
                )
                
            except asyncio.TimeoutError:
                continue
            except Exception as e:
                logger.error(f"Indexer error: {e}")
                await self.db.rollback()
                await asyncio.sleep(5)
    
    def stop(self):
        """Stop the indexer."""
        self.is_running = False
        self._stop_event.set()
