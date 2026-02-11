"""
Application configuration using Pydantic Settings.
"""
from typing import List, Optional
from pydantic import Field
from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""
    
    # App
    APP_NAME: str = "StakeFlow Backend"
    APP_ENV: str = "development"
    DEBUG: bool = True
    LOG_LEVEL: str = "INFO"
    
    # Server
    HOST: str = "0.0.0.0"
    PORT: int = 8000
    RELOAD: bool = True
    
    # Ethereum Mainnet
    ETHEREUM_RPC_URL: Optional[str] = None
    ETHEREUM_CHAIN_ID: int = 1
    ETHEREUM_STAKING_CONTRACT: Optional[str] = None
    ETHEREUM_REWARD_TOKEN: Optional[str] = None
    
    # Arbitrum
    ARBITRUM_RPC_URL: Optional[str] = None
    ARBITRUM_CHAIN_ID: int = 42161
    ARBITRUM_STAKING_CONTRACT: Optional[str] = None
    ARBITRUM_REWARD_TOKEN: Optional[str] = None
    
    # Base
    BASE_RPC_URL: Optional[str] = None
    BASE_CHAIN_ID: int = 8453
    BASE_STAKING_CONTRACT: Optional[str] = None
    BASE_REWARD_TOKEN: Optional[str] = None
    
    # Sepolia
    SEPOLIA_RPC_URL: Optional[str] = None
    SEPOLIA_CHAIN_ID: int = 11155111
    SEPOLIA_STAKING_CONTRACT: Optional[str] = None
    SEPOLIA_REWARD_TOKEN: Optional[str] = None
    
    # Default chain
    DEFAULT_CHAIN: str = "sepolia"
    
    # Database
    DATABASE_URL: str = "sqlite+aiosqlite:///./stakeflow.db"
    
    # Redis
    REDIS_URL: str = "redis://localhost:6379/0"
    
    # Indexing
    INDEXER_BATCH_SIZE: int = 1000
    INDEXER_POLL_INTERVAL: int = 15
    INDEX_START_BLOCK: int = 0
    
    # Security
    API_KEY_HEADER: str = "X-API-Key"
    ALLOWED_API_KEYS: str = ""
    
    # Monitoring
    SENTRY_DSN: Optional[str] = None
    METRICS_ENABLED: bool = True
    
    @property
    def allowed_api_keys(self) -> List[str]:
        """Parse comma-separated API keys."""
        return [k.strip() for k in self.ALLOWED_API_KEYS.split(",") if k.strip()]
    
    @property
    def chain_configs(self) -> dict:
        """Get chain configurations."""
        return {
            "ethereum": {
                "rpc_url": self.ETHEREUM_RPC_URL,
                "chain_id": self.ETHEREUM_CHAIN_ID,
                "staking_contract": self.ETHEREUM_STAKING_CONTRACT,
                "reward_token": self.ETHEREUM_REWARD_TOKEN,
            },
            "arbitrum": {
                "rpc_url": self.ARBITRUM_RPC_URL,
                "chain_id": self.ARBITRUM_CHAIN_ID,
                "staking_contract": self.ARBITRUM_STAKING_CONTRACT,
                "reward_token": self.ARBITRUM_REWARD_TOKEN,
            },
            "base": {
                "rpc_url": self.BASE_RPC_URL,
                "chain_id": self.BASE_CHAIN_ID,
                "staking_contract": self.BASE_STAKING_CONTRACT,
                "reward_token": self.BASE_REWARD_TOKEN,
            },
            "sepolia": {
                "rpc_url": self.SEPOLIA_RPC_URL,
                "chain_id": self.SEPOLIA_CHAIN_ID,
                "staking_contract": self.SEPOLIA_STAKING_CONTRACT,
                "reward_token": self.SEPOLIA_REWARD_TOKEN,
            },
        }
    
    def get_chain_config(self, chain: str) -> dict:
        """Get configuration for a specific chain."""
        config = self.chain_configs.get(chain.lower())
        if not config or not config.get("rpc_url"):
            raise ValueError(f"Configuration not found for chain: {chain}")
        return config
    
    class Config:
        env_file = ".env"
        case_sensitive = True


@lru_cache()
def get_settings() -> Settings:
    """Get cached settings instance."""
    return Settings()
