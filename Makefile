.PHONY: all install test build deploy clean help

# Default target
all: install build test

# Help
help:
	@echo "StakeFlow DeFi Platform - Available Commands:"
	@echo ""
	@echo "  make install      - Install all dependencies"
	@echo "  make test         - Run all tests"
	@echo "  make build        - Build all components"
	@echo "  make deploy       - Deploy contracts (requires env vars)"
	@echo "  make clean        - Clean build artifacts"
	@echo "  make dev          - Start development servers"
	@echo "  make format       - Format code"
	@echo "  make lint         - Lint code"
	@echo ""

# Install dependencies
install: install-contracts install-frontend install-backend

install-contracts:
	@echo "Installing contract dependencies..."
	forge install

install-frontend:
	@echo "Installing frontend dependencies..."
	cd frontend && npm install

install-backend:
	@echo "Installing backend dependencies..."
	cd backend && pip install -r requirements.txt

# Testing
test: test-contracts test-backend

test-contracts:
	@echo "Running contract tests..."
	forge test -vvv

test-backend:
	@echo "Running backend tests..."
	cd backend && pytest -v

# Building
build: build-contracts build-frontend

build-contracts:
	@echo "Building contracts..."
	forge build

build-frontend:
	@echo "Building frontend..."
	cd frontend && npm run build

# Deployment
deploy:
	@echo "Deploying contracts..."
	forge script scripts/Deploy.s.sol --broadcast --verify

deploy-sepolia:
	@echo "Deploying to Sepolia..."
	forge script scripts/Deploy.s.sol --rpc-url $(SEPOLIA_RPC_URL) --broadcast --verify

deploy-mainnet:
	@echo "Deploying to Mainnet..."
	forge script scripts/Deploy.s.sol --rpc-url $(MAINNET_RPC_URL) --broadcast --verify

# Development servers
dev: dev-frontend dev-backend

dev-frontend:
	@echo "Starting frontend dev server..."
	cd frontend && npm run dev &

dev-backend:
	@echo "Starting backend dev server..."
	cd backend && python -m src.main &

# Code quality
format: format-contracts format-frontend format-backend

format-contracts:
	@echo "Formatting contracts..."
	forge fmt

format-frontend:
	@echo "Formatting frontend..."
	cd frontend && npm run format

format-backend:
	@echo "Formatting backend..."
	cd backend && black src/ tests/

lint: lint-contracts lint-frontend lint-backend

lint-contracts:
	@echo "Linting contracts..."
	forge fmt --check

lint-frontend:
	@echo "Linting frontend..."
	cd frontend && npm run lint

lint-backend:
	@echo "Linting backend..."
	cd backend && flake8 src/ tests/

# Gas reporting
gas:
	@echo "Generating gas report..."
	forge test --gas-report

# Coverage
coverage:
	@echo "Running coverage..."
	forge coverage

# Cleaning
clean: clean-contracts clean-frontend clean-backend

clean-contracts:
	@echo "Cleaning contract artifacts..."
	forge clean

clean-frontend:
	@echo "Cleaning frontend build..."
	rm -rf frontend/dist

clean-backend:
	@echo "Cleaning backend cache..."
	find backend -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	rm -rf backend/.mypy_cache
	rm -rf backend/.pytest_cache

# Database
db-init:
	@echo "Initializing database..."
	cd backend && python -c "from src.models.database import init_db; import asyncio; asyncio.run(init_db())"

db-migrate:
	@echo "Running database migrations..."
	cd backend && alembic upgrade head

# Docker
docker-build:
	@echo "Building Docker images..."
	docker build -t stakeflow-backend ./backend

docker-up:
	@echo "Starting Docker containers..."
	docker-compose up -d

docker-down:
	@echo "Stopping Docker containers..."
	docker-compose down

# Snapshot
gas-snapshot:
	@echo "Creating gas snapshot..."
	forge snapshot

# Security
slither:
	@echo "Running Slither analysis..."
	slither contracts/
