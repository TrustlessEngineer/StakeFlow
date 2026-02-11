# How StakeFlow Works - Complete Guide

## 🎯 Problems StakeFlow Solves

### 1. **Idle Crypto Assets**
**Problem**: Users hold tokens that don't generate yield
**Solution**: StakeFlow allows staking any ERC20 token to earn rewards

### 2. **Complex DeFi Protocols**
**Problem**: Existing staking platforms are complicated for beginners
**Solution**: Simple 3-step process: Connect → Stake → Earn

### 3. **Impermanent Loss Risk**
**Problem**: LP staking carries impermanent loss
**Solution**: Single-asset staking - no LP tokens needed

### 4. **Low Liquidity for New Tokens**
**Problem**: New projects struggle to bootstrap liquidity
**Solution**: Projects can create staking pools to incentivize holding

### 5. **No Auto-Compounding**
**Problem**: Manual compounding is gas-expensive and tedious
**Solution**: One-click compound function for maximum APY

---

## ⚙️ How It Works (Step-by-Step)

### Architecture Flow

```
┌─────────────┐     ┌─────────────┐     ┌─────────────────┐
│    USER     │────►│   STAKE     │────►│  STAKEFLOW      │
│   WALLET    │     │   TOKENS    │     │  SMART CONTRACT │
└─────────────┘     └─────────────┘     └─────────────────┘
                                               │
                       ┌───────────────────────┼───────────────────────┐
                       ▼                       ▼                       ▼
                ┌─────────────┐        ┌─────────────┐        ┌─────────────┐
                │   LOCK      │        │   EARN      │        │   EMERGENCY │
                │   PERIOD    │        │   REWARDS   │        │   EXIT      │
                │   (7-90d)   │        │   (Auto)    │        │   (10% fee) │
                └─────────────┘        └─────────────┘        └─────────────┘
```

### Detailed User Journey

#### 1. **Connect Wallet**
```
User → RainbowKit → MetaMask/WalletConnect → Wallet Connected
```

#### 2. **View Available Pools**
```
Frontend → Backend API → Database/Blockchain → Pool List
```

#### 3. **Approve Token Spending**
```
User → Approve USDC → Smart Contract gets allowance
```

#### 4. **Stake Tokens**
```
User clicks "Stake 1000 USDC"
    ↓
Frontend calls stake(0, 1000000000)  [poolId, amount]
    ↓
Smart Contract:
    - Takes 1000 USDC
    - Deducts 1% fee (10 USDC) → Fee Recipient
    - Stakes 990 USDC
    - Sets unlock time (current + 7 days)
    - Emits Staked event
    ↓
Backend Indexer catches event
    ↓
User sees position in Portfolio
```

#### 5. **Earn Rewards**
```
Every Second:
    rewardPerToken += (rewardRate * timeElapsed) / totalStaked

User's Pending Rewards:
    pending = (stakedAmount * rewardPerToken) / 1e12 - rewardDebt
```

**Example Calculation:**
- Pool reward rate: 1 token/second
- Total staked: 10,000 tokens
- User staked: 1,000 tokens
- Time elapsed: 1 day (86,400 seconds)

```
Rewards per token = (1 * 86,400) / 10,000 = 8.64 tokens per token staked
User rewards = 1,000 * 8.64 = 8,640 tokens
```

#### 6. **Claim or Compound**
```
Claim:
    User → claimRewards(poolId) → Rewards transferred to wallet

Compound (if staking token = reward token):
    User → compound(poolId) → Rewards added to stake → Higher APY
```

#### 7. **Withdraw**
```
After Lock Period:
    User → withdraw(poolId, amount)
    ↓
    Smart Contract:
        - Calculates final rewards
        - Deducts withdraw fee (1%)
        - Transfers tokens + rewards
        - Updates user position

Before Lock Period (Emergency):
    User → emergencyWithdraw(poolId)
    ↓
    Smart Contract:
        - Returns 90% of stake
        - 10% penalty to fee recipient
        - All rewards forfeited
```

---

## 💰 Token Economics

### For Stakers
| Action | Fee/Reward |
|--------|-----------|
| Stake | 1% deposit fee |
| Normal Withdraw | 1% withdraw fee |
| Emergency Withdraw | 10% penalty |
| Claim Rewards | 0% free |
| Compound | 0% free |

### For Pool Creators
```
Requirements:
    - Reward tokens (funded by creator)
    - Set reward rate and duration
    - Define lock period

Example:
    Creator adds 100,000 SFT for 90 days
    Reward rate = 100,000 / 90 days = 1.157 tokens/second
    APY depends on total staked amount
```

---

## 🔐 Security Mechanisms

### 1. **Reentrancy Protection**
```solidity
function withdraw(uint256 _poolId, uint256 _amount) 
    external 
    nonReentrant  // ← Prevents reentrancy attacks
    whenNotPaused
{
    // ... logic
}
```

### 2. **Access Control**
```solidity
function createPool(...) external onlyOwner { }
function addRewards(...) external onlyDistributor { }
```

### 3. **Emergency Pause**
```solidity
function pause() external onlyOwner {
    _pause();  // ← Stops all staking operations
}
```

### 4. **Input Validation**
```solidity
require(_amount > 0, "Amount must be > 0");
require(pool.isActive, "Pool not active");
require(block.timestamp >= user.unlockTime, "Tokens locked");
```

---

## 📊 Data Flow

### Frontend ↔ Backend ↔ Blockchain

```
┌──────────┐    HTTP    ┌──────────┐    RPC    ┌──────────┐
│ Frontend │◄──────────►│ Backend  │◄─────────►│ Blockchain│
└──────────┘            └──────────┘           └──────────┘
                              │
                              ▼ SQL
                        ┌──────────┐
                        │ Database │
                        │ (History)│
                        └──────────┘
```

### Event Indexing
```
Blockchain Event
    ↓
Backend Indexer (polls every 15 seconds)
    ↓
Parse event → Store in PostgreSQL
    ↓
API serves historical data to Frontend
```

---

## 🚀 Launch on Your System - Complete Steps

### Prerequisites Check

```bash
# Check if you have these installed
node --version      # Should be v18+
python --version    # Should be 3.11+
forge --version     # Should show foundry version
git --version       # Any recent version
```

If missing any, install:
- **Node.js**: https://nodejs.org/
- **Python**: https://python.org/
- **Foundry**: `curl -L https://foundry.paradigm.xyz | bash`
- **Git**: https://git-scm.com/

---

### Step 1: Clone and Setup

```bash
# Open terminal/command prompt
# Navigate to where you want the project
cd ~/Documents

# Clone the project (we'll create the repo structure)
mkdir StakeFlow
cd StakeFlow

# Initialize git
git init

# Create directory structure
mkdir -p contracts tests scripts frontend/src/components frontend/src/hooks frontend/src/utils frontend/src/abis backend/src/api backend/src/core backend/src/models backend/src/services
```

---

### Step 2: Install Dependencies

```bash
# In the StakeFlow directory

# 1. Install Foundry dependencies (OpenZeppelin)
forge install OpenZeppelin/openzeppelin-contracts --no-commit

# 2. Setup Frontend
cd frontend
npm create vite@latest . -- --template react-ts
npm install
npm install @rainbow-me/rainbowkit wagmi viem @tanstack/react-query lucide-react clsx tailwind-merge recharts
npm install -D tailwindcss postcss autoprefixer @types/node
npx tailwindcss init -p
cd ..

# 3. Setup Backend
cd backend
python -m venv venv

# On Windows:
venv\Scripts\activate
# On Mac/Linux:
source venv/bin/activate

# Create requirements.txt and install
pip install web3 fastapi uvicorn sqlalchemy aiosqlite python-dotenv pydantic pydantic-settings

cd ..
```

---

### Step 3: Configure Environment

```bash
# Backend environment
cd backend

# Create .env file
cat > .env << EOL
APP_NAME=StakeFlow Backend
APP_ENV=development
DEBUG=true

# Use public RPC or get free one from Alchemy/Infura
SEPOLIA_RPC_URL=https://eth-sepolia.public.blastapi.io
SEPOLIA_CHAIN_ID=11155111
DEFAULT_CHAIN=sepolia

DATABASE_URL=sqlite+aiosqlite:///./stakeflow.db
REDIS_URL=redis://localhost:6379/0

HOST=0.0.0.0
PORT=8000
RELOAD=true
EOL

cd ..

# Frontend environment
cd frontend

# Create .env.local
cat > .env.local << EOL
VITE_WC_PROJECT_ID=YOUR_WALLETCONNECT_PROJECT_ID

# Use public Sepolia RPC
VITE_SEPOLIA_RPC=https://eth-sepolia.public.blastapi.io

# We'll update these after contract deployment
VITE_SEPOLIA_STAKING=0x...
VITE_SEPOLIA_REWARD_TOKEN=0x...
EOL

cd ..
```

---

### Step 4: Deploy to Sepolia Testnet

```bash
# 1. Get Sepolia ETH from faucet:
# https://sepoliafaucet.com/ (need Alchemy account)
# https://faucet.sepolia.dev/

# 2. Set your private key (NEVER commit this!)
export PRIVATE_KEY=your_private_key_here
export OWNER_ADDRESS=your_wallet_address
export FEE_RECIPIENT=your_wallet_address

# 3. Deploy contracts
forge script scripts/Deploy.s.sol \
  --rpc-url https://eth-sepolia.public.blastapi.io \
  --broadcast \
  --private-key $PRIVATE_KEY

# 4. Save the deployed addresses output
# You'll see something like:
# Reward Token deployed at: 0x1234...
# Staking Contract deployed at: 0x5678...
```

---

### Step 5: Update Frontend with Contract Addresses

```bash
# Edit frontend/.env.local with deployed addresses
# Example:
VITE_SEPOLIA_STAKING=0x1234567890abcdef...
VITE_SEPOLIA_REWARD_TOKEN=0xfedcba0987654321...
```

---

### Step 6: Run Everything

```bash
# Terminal 1: Start Backend
cd backend
source venv/bin/activate  # or venv\Scripts\activate on Windows
python -m src.main

# Backend will start at http://localhost:8000

# Terminal 2: Start Frontend
cd frontend
npm run dev

# Frontend will start at http://localhost:5173

# Open browser and go to http://localhost:5173
```

---

### Step 7: Test the Flow

```
1. Connect MetaMask (switch to Sepolia network)
2. Get test tokens (we'll create a faucet script)
3. Approve tokens for staking
4. Stake tokens
5. Watch rewards accumulate
6. Try claiming/compounding
7. Test withdrawal after lock period
```

---

## 📤 Upload to GitHub

### Step 1: Prepare for GitHub

```bash
# In StakeFlow directory

# Create .gitignore
cat > .gitignore << 'EOL'
# Dependencies
node_modules/
venv/
__pycache__/
lib/

# Build outputs
out/
dist/
build/
*.exe

# Environment (IMPORTANT - never commit these!)
.env
.env.local

# IDE
.vscode/
.idea/

# OS
.DS_Store

# Database
*.db
*.sqlite

# Foundry
cache/
broadcast/
EOL

# Make sure private keys are not in any file
grep -r "PRIVATE_KEY" . --include="*.sol" --include="*.py" --include="*.ts" --include="*.sh" || echo "Good - no private keys found"
```

---

### Step 2: Create GitHub Repository

```bash
# 1. Create repo on GitHub (without README)
# Go to: https://github.com/new
# Name: StakeFlow
# Keep it Public or Private
# Don't initialize with README

# 2. Connect local to GitHub
git init
git add .
git commit -m "Initial commit: StakeFlow DeFi staking platform"

# Replace with your actual GitHub username
git remote add origin https://github.com/YOUR_USERNAME/StakeFlow.git
git branch -M main
git push -u origin main
```

---

### Step 3: GitHub Actions (Auto CI/CD)

```bash
# The .github/workflows/test.yml is already created
# It will automatically:
# - Run contract tests on every push
# - Build frontend
# - Run backend tests

# Check status on GitHub → Actions tab after pushing
```

---

### Step 4: Add Screenshots to README

```bash
# After you run the app locally:
# 1. Take screenshots of:
#    - Dashboard
#    - Pool cards
#    - Portfolio view
# 
# 2. Create assets folder
mkdir -p assets/screenshots
# Save screenshots there

# 3. Update README.md to include screenshots
git add assets/
git commit -m "Add screenshots"
git push
```

---

## 🎓 Learning Path

### Week 1: Understand the Code
- [ ] Read through StakeFlowStaking.sol line by line
- [ ] Run `forge test -vvv` and watch tests pass
- [ ] Modify a test and see it fail

### Week 2: Frontend Integration
- [ ] Connect wallet successfully
- [ ] Display balance from blockchain
- [ ] Implement stake transaction

### Week 3: Backend & Indexing
- [ ] Set up database
- [ ] Run indexer locally
- [ ] Query API endpoints

### Week 4: Deploy & Share
- [ ] Deploy to Sepolia
- [ ] Record demo video
- [ ] Share on Twitter/LinkedIn

---

## ❓ Common Issues & Solutions

### Issue 1: "Module not found" in Frontend
```bash
# Solution: Install missing dependencies
cd frontend
npm install
```

### Issue 2: "RPC error" in Backend
```bash
# Solution: Use different RPC URL
# Try these free Sepolia RPCs:
# - https://eth-sepolia.public.blastapi.io
# - https://rpc.sepolia.org
# - https://sepolia.gateway.tenderly.co
```

### Issue 3: "Out of gas" on deployment
```bash
# Solution: You need Sepolia ETH
# Get from: https://sepoliafaucet.com/
```

### Issue 4: Git push rejected
```bash
# Solution: Force push first time only
git push -u origin main --force
```

---

## 📞 Next Steps

1. **Run locally**: Follow Step 1-6 above
2. **Modify something**: Change the UI color, add a new feature
3. **Write about it**: Create a blog post explaining what you built
4. **Deploy to mainnet**: After thorough testing (requires real ETH)
5. **Get audited**: Before handling real user funds

---

**Need help with any specific step?** Just ask!
