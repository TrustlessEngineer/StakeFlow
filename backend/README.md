# StakeFlow Backend

Python backend for StakeFlow with FastAPI, Web3.py, and event indexing.

## Features

- 🚀 FastAPI async API
- 🔗 Web3.py blockchain integration
- 📊 Event indexer for analytics
- 🗄️ SQLAlchemy database
- 📈 REST API endpoints

## Development

```bash
# Install dependencies
pip install -r requirements.txt

# Setup environment
cp .env.example .env
# Edit .env with your configuration

# Run development server
python -m src.main

# Run tests
pytest
```

## API Documentation

Once running, visit:
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

## Architecture

```
src/
├── api/            # FastAPI routes
├── core/           # Configuration
├── models/         # Database models
├── services/       # Business logic
└── main.py         # App entry
```

## Indexer

The indexer service processes blockchain events and stores them in the database for analytics.

```python
# Start indexer
python -m src.services.indexer
```
