"""
API routes for StakeFlow backend.
"""
from typing import List, Optional
from decimal import Decimal
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, desc
from pydantic import BaseModel, Field

from src.services.blockchain import get_blockchain_service, BlockchainService
from src.models.database import Pool, Stake, StakingEvent, DailyStats, get_db

router = APIRouter(prefix="/api/v1")


# Pydantic Models
class PoolResponse(BaseModel):
    id: int
    pool_id: int
    chain: str
    staking_token: str
    reward_token: str
    total_staked: str
    reward_rate: str
    lock_duration: int
    deposit_fee: int
    withdraw_fee: int
    is_active: bool
    apy: Optional[float] = None
    
    class Config:
        from_attributes = True


class UserStakeResponse(BaseModel):
    pool_id: int
    staked_amount: str
    pending_rewards: str
    unlock_time: Optional[datetime] = None
    is_locked: bool


class StakingEventResponse(BaseModel):
    id: int
    event_type: str
    tx_hash: str
    block_number: int
    pool_id: int
    user_address: str
    amount: Optional[str]
    reward_amount: Optional[str]
    timestamp: datetime
    
    class Config:
        from_attributes = True


class ProtocolStats(BaseModel):
    chain: str
    total_staked: str
    total_pools: int
    total_stakers: int
    total_rewards_distributed: str


class StakeRequest(BaseModel):
    pool_id: int
    amount: str = Field(..., description="Amount in wei")


class WithdrawRequest(BaseModel):
    pool_id: int
    amount: str = Field(..., description="Amount in wei")


# Database dependency
async def get_db_session():
    """Get database session."""
    from src.models.database import async_session
    async with async_session() as session:
        yield session


# Routes
@router.get("/health")
async def health_check():
    """Health check endpoint."""
    return {"status": "ok", "timestamp": datetime.utcnow()}


@router.get("/chains")
async def get_supported_chains():
    """Get supported blockchain networks."""
    return {
        "chains": [
            {"id": "ethereum", "name": "Ethereum Mainnet", "chain_id": 1},
            {"id": "arbitrum", "name": "Arbitrum One", "chain_id": 42161},
            {"id": "base", "name": "Base", "chain_id": 8453},
            {"id": "sepolia", "name": "Sepolia Testnet", "chain_id": 11155111},
        ]
    }


# Pool Routes
@router.get("/pools", response_model=List[PoolResponse])
async def get_pools(
    chain: str = Query(..., description="Blockchain network"),
    active_only: bool = Query(True, description="Only active pools"),
    db: AsyncSession = Depends(get_db_session)
):
    """Get all staking pools for a chain."""
    query = select(Pool).where(Pool.chain == chain.lower())
    
    if active_only:
        query = query.where(Pool.is_active == True)
    
    result = await db.execute(query)
    pools = result.scalars().all()
    
    # Fetch APY from blockchain
    try:
        blockchain = get_blockchain_service(chain)
        response_pools = []
        for pool in pools:
            pool_data = PoolResponse.from_orm(pool)
            pool_info = blockchain.get_pool_info(pool.pool_id)
            if pool_info:
                pool_data.apy = float(pool_info.apy) / 100  # Convert from bps
            response_pools.append(pool_data)
        return response_pools
    except Exception as e:
        # Return pools without APY if blockchain unavailable
        return [PoolResponse.from_orm(pool) for pool in pools]


@router.get("/pools/{pool_id}", response_model=PoolResponse)
async def get_pool(
    pool_id: int,
    chain: str = Query(..., description="Blockchain network"),
    db: AsyncSession = Depends(get_db_session)
):
    """Get specific pool details."""
    result = await db.execute(
        select(Pool).where(
            Pool.chain == chain.lower(),
            Pool.pool_id == pool_id
        )
    )
    pool = result.scalar_one_or_none()
    
    if not pool:
        raise HTTPException(status_code=404, detail="Pool not found")
    
    pool_response = PoolResponse.from_orm(pool)
    
    # Fetch fresh data from blockchain
    try:
        blockchain = get_blockchain_service(chain)
        pool_info = blockchain.get_pool_info(pool_id)
        if pool_info:
            pool_response.total_staked = str(pool_info.total_staked)
            pool_response.apy = float(pool_info.apy) / 100
    except Exception:
        pass
    
    return pool_response


@router.get("/pools/{pool_id}/stats")
async def get_pool_stats(
    pool_id: int,
    chain: str = Query(..., description="Blockchain network"),
    db: AsyncSession = Depends(get_db_session)
):
    """Get pool statistics."""
    # Get unique stakers count
    stakers_result = await db.execute(
        select(func.count(func.distinct(Stake.user_address)))
        .where(
            Stake.chain == chain.lower(),
            Stake.pool_id == pool_id,
            Stake.is_active == True
        )
    )
    unique_stakers = stakers_result.scalar()
    
    # Get total staked from DB
    total_result = await db.execute(
        select(func.sum(Stake.staked_amount))
        .where(
            Stake.chain == chain.lower(),
            Stake.pool_id == pool_id,
            Stake.is_active == True
        )
    )
    total_staked = total_result.scalar() or 0
    
    # Get recent events
    events_result = await db.execute(
        select(StakingEvent)
        .where(
            StakingEvent.chain == chain.lower(),
            StakingEvent.pool_id == pool_id
        )
        .order_by(desc(StakingEvent.timestamp))
        .limit(10)
    )
    recent_events = events_result.scalars().all()
    
    return {
        "pool_id": pool_id,
        "chain": chain,
        "unique_stakers": unique_stakers,
        "total_staked": str(total_staked),
        "recent_events": [StakingEventResponse.from_orm(e) for e in recent_events]
    }


# User Routes
@router.get("/users/{user_address}/stakes", response_model=List[UserStakeResponse])
async def get_user_stakes(
    user_address: str,
    chain: str = Query(..., description="Blockchain network"),
    db: AsyncSession = Depends(get_db_session)
):
    """Get all stakes for a user."""
    result = await db.execute(
        select(Stake, Pool.pool_id)
        .join(Pool, Stake.pool_id == Pool.id)
        .where(
            Stake.chain == chain.lower(),
            Stake.user_address == user_address.lower(),
            Stake.is_active == True
        )
    )
    stakes = result.all()
    
    current_time = datetime.utcnow()
    
    return [
        UserStakeResponse(
            pool_id=pool_id,
            staked_amount=str(stake.staked_amount),
            pending_rewards=str(stake.pending_rewards),
            unlock_time=stake.unlock_time,
            is_locked=stake.unlock_time and stake.unlock_time > current_time
        )
        for stake, pool_id in stakes
    ]


@router.get("/users/{user_address}/positions")
async def get_user_positions(
    user_address: str,
    chain: str = Query(..., description="Blockchain network")
):
    """Get user positions directly from blockchain."""
    try:
        blockchain = get_blockchain_service(chain)
        positions = blockchain.get_user_positions(user_address)
        
        # Enrich with pool data
        enriched_positions = []
        for i, pool_id in enumerate(positions["pool_ids"]):
            pool_info = blockchain.get_pool_info(pool_id)
            enriched_positions.append({
                "pool_id": pool_id,
                "staked_amount": str(positions["stakes"][i]),
                "pending_rewards": str(positions["rewards"][i]),
                "pool_name": f"Pool #{pool_id}",
                "apy": float(pool_info.apy) / 100 if pool_info else 0
            })
        
        return {
            "user_address": user_address,
            "chain": chain,
            "positions": enriched_positions
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error fetching positions: {str(e)}")


@router.get("/users/{user_address}/history", response_model=List[StakingEventResponse])
async def get_user_history(
    user_address: str,
    chain: str = Query(..., description="Blockchain network"),
    event_type: Optional[str] = Query(None, description="Filter by event type"),
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_db_session)
):
    """Get staking history for a user."""
    query = select(StakingEvent).where(
        StakingEvent.chain == chain.lower(),
        StakingEvent.user_address == user_address.lower()
    )
    
    if event_type:
        query = query.where(StakingEvent.event_type == event_type)
    
    query = query.order_by(desc(StakingEvent.timestamp)).offset(offset).limit(limit)
    
    result = await db.execute(query)
    events = result.scalars().all()
    
    return [StakingEventResponse.from_orm(e) for e in events]


# Events Routes
@router.get("/events", response_model=List[StakingEventResponse])
async def get_events(
    chain: str = Query(..., description="Blockchain network"),
    event_type: Optional[str] = Query(None, description="Event type filter"),
    pool_id: Optional[int] = Query(None, description="Pool ID filter"),
    user_address: Optional[str] = Query(None, description="User address filter"),
    from_block: Optional[int] = Query(None),
    to_block: Optional[int] = Query(None),
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_db_session)
):
    """Get staking events with filters."""
    query = select(StakingEvent).where(StakingEvent.chain == chain.lower())
    
    if event_type:
        query = query.where(StakingEvent.event_type == event_type)
    if pool_id is not None:
        query = query.where(StakingEvent.pool_id == pool_id)
    if user_address:
        query = query.where(StakingEvent.user_address == user_address.lower())
    if from_block:
        query = query.where(StakingEvent.block_number >= from_block)
    if to_block:
        query = query.where(StakingEvent.block_number <= to_block)
    
    query = query.order_by(desc(StakingEvent.timestamp)).offset(offset).limit(limit)
    
    result = await db.execute(query)
    events = result.scalars().all()
    
    return [StakingEventResponse.from_orm(e) for e in events]


# Stats Routes
@router.get("/stats")
async def get_protocol_stats(
    chain: str = Query(..., description="Blockchain network"),
    db: AsyncSession = Depends(get_db_session)
):
    """Get protocol statistics."""
    # Total pools
    pools_result = await db.execute(
        select(func.count(Pool.id)).where(Pool.chain == chain.lower())
    )
    total_pools = pools_result.scalar()
    
    # Active stakes
    stakes_result = await db.execute(
        select(func.count(func.distinct(Stake.user_address)))
        .where(
            Stake.chain == chain.lower(),
            Stake.is_active == True
        )
    )
    total_stakers = stakes_result.scalar()
    
    # Total staked
    total_staked_result = await db.execute(
        select(func.sum(Stake.staked_amount))
        .where(
            Stake.chain == chain.lower(),
            Stake.is_active == True
        )
    )
    total_staked = total_staked_result.scalar() or 0
    
    # Rewards distributed (from events)
    rewards_result = await db.execute(
        select(func.sum(StakingEvent.reward_amount))
        .where(
            StakingEvent.chain == chain.lower(),
            StakingEvent.event_type.in_(["Withdrawn", "RewardClaimed"])
        )
    )
    total_rewards = rewards_result.scalar() or 0
    
    return ProtocolStats(
        chain=chain,
        total_staked=str(total_staked),
        total_pools=total_pools,
        total_stakers=total_stakers,
        total_rewards_distributed=str(total_rewards)
    )


@router.get("/stats/historical")
async def get_historical_stats(
    chain: str = Query(..., description="Blockchain network"),
    days: int = Query(30, ge=1, le=365),
    db: AsyncSession = Depends(get_db_session)
):
    """Get historical protocol statistics."""
    from datetime import timedelta
    
    since = datetime.utcnow() - timedelta(days=days)
    
    result = await db.execute(
        select(DailyStats)
        .where(
            DailyStats.chain == chain.lower(),
            DailyStats.date >= since
        )
        .order_by(DailyStats.date)
    )
    stats = result.scalars().all()
    
    return {
        "chain": chain,
        "period_days": days,
        "data": [
            {
                "date": stat.date.isoformat(),
                "total_staked": str(stat.total_staked),
                "rewards_distributed": str(stat.total_rewards_distributed),
                "unique_stakers": stat.unique_stakers,
                "new_stakes": stat.new_stakes,
                "withdrawals": stat.withdrawals
            }
            for stat in stats
        ]
    }


# Token price simulation (would integrate with price oracle)
@router.get("/prices/{token_address}")
async def get_token_price(
    token_address: str,
    chain: str = Query(..., description="Blockchain network")
):
    """Get token price (mock implementation)."""
    # In production, integrate with CoinGecko, Chainlink, etc.
    return {
        "token_address": token_address,
        "chain": chain,
        "price_usd": "1.00",  # Mock price
        "timestamp": datetime.utcnow()
    }
