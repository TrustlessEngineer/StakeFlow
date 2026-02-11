# 🌊 StakeFlow - DeFi Staking Platform

StakeFlow is a production-ready DeFi staking protocol built with **Solidity**, **Foundry**, **React + Wagmi**, and **Python (Web3.py)**. It supports multi-pool staking with time-weighted rewards, auto-compounding, emergency withdrawal mechanisms, and comprehensive gas optimization.

## 📋 Table of Contents

- [Features](#features)
- [Architecture](#architecture)
- [Quick Start](#quick-start)
- [Smart Contracts](#smart-contracts)
- [Frontend](#frontend)
- [Backend](#backend)
- [Deployment](#deployment)
- [Security](#security)
- [License](#license)

## ✨ Features

### Smart Contracts
- ✅ **Multi-pool staking** with configurable APYs
- ✅ **Time-weighted reward distribution** with precision calculations
- ✅ **Auto-compounding** for reinvesting rewards
- ✅ **Emergency withdrawal** with penalty mechanism
- ✅ **Deposit/withdraw fees** for protocol sustainability
- ✅ **Reentrancy protection** with OpenZeppelin's ReentrancyGuard
- ✅ **Pausable functionality** for emergency stops
- ✅ **Gas-optimized** implementation

### Frontend
- ✅ **Modern React + TypeScript** with Vite
- ✅ **RainbowKit + Wagmi** for wallet connection
- ✅ **Real-time APY calculations**
- ✅ **Portfolio tracking** across all pools
- ✅ **Responsive design** with Tailwind CSS

### Backend
- ✅ **FastAPI** with async Python
- ✅ **Web3.py** blockchain integration
- ✅ **Event indexer** for historical data
- ✅ **Database models** for analytics
- ✅ **REST API** for protocol data

## 🏗️ Architecture

```
StakeFlow/
├── contracts/              # Solidity smart contracts
│   ├── StakeFlowStaking.sol    # Main staking contract
│   ├── StakeFlowToken.sol      # Reward token
│   └── IStakeFlowStaking.sol   # Interface
├── tests/                  # Foundry test suite
├── frontend/               # React frontend
│   ├── src/
│   │   ├── components/     # React components
│   │   ├── hooks/          # Web3 hooks
│   │   └── utils/          # Utilities
│   └── package.json
├── backend/                # Python backend
│   ├── src/
│   │   ├── api/            # FastAPI routes
│   │   ├── services/       # Blockchain & indexer
│   │   └── models/         # Database models
│   └── requirements.txt
└── scripts/                # Deployment scripts
```

## 🚀 Quick Start

### Prerequisites

- [Node.js](https://nodejs.org/) (v18+)
- [Foundry](https://book.getfoundry.sh/)
- [Python](https://python.org/) (3.11+)
- [Git](https://git-scm.com/)

### 1. Clone & Setup

```bash
git clone https://github.com/yourusername/stakeflow.git
cd stakeflow

# Install contract dependencies
forge install

# Install frontend dependencies
cd frontend && npm install

# Install backend dependencies
cd ../backend && pip install -r requirements.txt
```

### 2. Environment Setup

```bash
# Backend environment
cd backend
cp .env.example .env
# Edit .env with your RPC URLs and contract addresses

# Frontend environment
cd ../frontend
cp .env.example .env.local
# Edit .env.local with your contract addresses
```

### 3. Run Tests

```bash
# Smart contract tests
forge test -vvv

# Backend tests
cd backend
pytest

# Frontend tests
cd ../frontend
npm run test
```

## 📜 Smart Contracts

### StakeFlowStaking

Main staking contract with the following features:

| Function | Description |
|----------|-------------|
| `createPool` | Create new staking pool (owner only) |
| `stake` | Stake tokens into a pool |
| `withdraw` | Withdraw staked tokens + rewards |
| `emergencyWithdraw` | Emergency withdrawal with 10% penalty |
| `claimRewards` | Claim pending rewards |
| `compound` | Compound rewards back into stake |
| `addRewards` | Add rewards to a pool (distributor) |

### Security Features

- **ReentrancyGuard**: Prevents reentrancy attacks
- **Pausable**: Emergency stop mechanism
- **Access Control**: Owner-only admin functions
- **Input Validation**: Comprehensive parameter checks
- **SafeERC20**: Safe token transfers

### Gas Optimization

- Storage packing for struct fields
- Efficient reward calculation algorithm
- Minimal storage writes
- Batch operations where possible

## 🖥️ Frontend

The frontend is built with:
- **React 18** + TypeScript
- **Vite** for fast development
- **Wagmi 2.0** + **Viem** for Web3
- **RainbowKit** for wallet connection
- **Tailwind CSS** for styling

### Key Components

| Component | Purpose |
|-----------|---------|
| `Dashboard` | Protocol overview & stats |
| `Pools` | Staking pool listings |
| `PoolCard` | Individual pool interactions |
| `Portfolio` | User position tracking |

### Development

```bash
cd frontend
npm run dev
```

## 🐍 Backend

The Python backend provides:
- **FastAPI** REST endpoints
- **Web3.py** blockchain integration
- **Event indexer** for real-time data
- **Database** for historical analytics

### Key Services

| Service | Description |
|---------|-------------|
| `BlockchainService` | Web3 interactions |
| `IndexerService` | Event indexing |
| `PoolService` | Pool data management |

### API Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /api/v1/pools` | List all pools |
| `GET /api/v1/pools/{id}` | Pool details |
| `GET /api/v1/users/{address}/stakes` | User stakes |
| `GET /api/v1/events` | Staking events |
| `GET /api/v1/stats` | Protocol statistics |

### Development

```bash
cd backend
python -m src.main
```

## 🚀 Deployment

### Contract Deployment

```bash
# Set environment variables
export PRIVATE_KEY=your_private_key
export OWNER_ADDRESS=your_address
export FEE_RECIPIENT=fee_recipient_address

# Deploy to Sepolia
forge script scripts/Deploy.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify

# Deploy to Mainnet
forge script scripts/Deploy.s.sol \
  --rpc-url $MAINNET_RPC_URL \
  --broadcast \
  --verify
```

### Frontend Deployment

```bash
cd frontend
npm run build
# Deploy dist/ to Vercel, Netlify, or IPFS
```

### Backend Deployment

```bash
cd backend
docker build -t stakeflow-backend .
docker run -p 8000:8000 stakeflow-backend
```

## 🔒 Security

### Audit Checklist

- [ ] Reentrancy protection
- [ ] Integer overflow/underflow
- [ ] Access control
- [ ] Token approval handling
- [ ] Emergency mechanisms
- [ ] Gas optimization
- [ ] Event emission

### Known Considerations

1. **Reward Token Supply**: Ensure sufficient reward tokens in contract
2. **Price Oracles**: Consider integrating Chainlink for token prices
3. **Upgradeability**: Current implementation is not upgradeable
4. **Governance**: Owner has significant control over pool parameters

## 📊 Gas Costs

| Operation | Gas Cost (approx) |
|-----------|-------------------|
| Stake | ~120,000 |
| Withdraw | ~100,000 |
| Claim Rewards | ~80,000 |
| Emergency Withdraw | ~70,000 |
| Compound | ~90,000 |

## 🧪 Testing

### Coverage Report

```bash
forge coverage
```

### Fuzz Testing

```bash
forge test --fuzz-runs 10000
```

### Integration Testing

```bash
# Start local node
anvil

# Run integration tests
forge test --fork-url http://localhost:8545
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🔗 Resources

- [Foundry Book](https://book.getfoundry.sh/)
- [Wagmi Documentation](https://wagmi.sh/)
- [Web3.py Documentation](https://web3py.readthedocs.io/)
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts)

---

<p align="center">
  Built with ❤️ for the DeFi community
</p>
