# Azure Translator Solution Accelerator - Makefile
# Common development and deployment tasks

.PHONY: help setup install clean test lint format validate deploy destroy local-run logs

# Default target
.DEFAULT_GOAL := help

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m # No Color

help: ## Show this help message
	@echo "$(BLUE)Azure Translator Solution Accelerator - Available Commands$(NC)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""

## Setup and Installation

setup: install-backend install-frontend ## Install all dependencies (backend + frontend)
	@echo "$(GREEN)✓ All dependencies installed$(NC)"

install-backend: ## Install backend Python dependencies
	@echo "$(BLUE)Installing backend dependencies...$(NC)"
	cd src/backend && pip install -r requirements.txt
	@echo "$(GREEN)✓ Backend dependencies installed$(NC)"

install-frontend: ## Install frontend Node dependencies
	@echo "$(BLUE)Installing frontend dependencies...$(NC)"
	cd src/frontend && npm install
	@echo "$(GREEN)✓ Frontend dependencies installed$(NC)"

install-dev: ## Install development dependencies
	@echo "$(BLUE)Installing development dependencies...$(NC)"
	cd src/backend && pip install -r requirements-dev.txt
	cd src/frontend && npm install --include=dev
	@echo "$(GREEN)✓ Development dependencies installed$(NC)"

## Local Development

local-run: ## Run application locally with Docker Compose
	@echo "$(BLUE)Starting application with Docker Compose...$(NC)"
	docker compose up --build

local-run-detached: ## Run application in background
	@echo "$(BLUE)Starting application in background...$(NC)"
	docker compose up -d --build
	@echo "$(GREEN)✓ Application running$(NC)"
	@echo "Backend:  http://localhost:8000"
	@echo "Frontend: http://localhost:3000"
	@echo "API Docs: http://localhost:8000/docs"

local-stop: ## Stop local Docker Compose services
	@echo "$(BLUE)Stopping services...$(NC)"
	docker compose down
	@echo "$(GREEN)✓ Services stopped$(NC)"

local-logs: ## View Docker Compose logs
	docker compose logs -f

run-backend: ## Run backend locally (without Docker)
	@echo "$(BLUE)Starting backend...$(NC)"
	cd src/backend && uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

run-frontend: ## Run frontend locally (without Docker)
	@echo "$(BLUE)Starting frontend...$(NC)"
	cd src/frontend && npm run dev

## Testing

test: test-backend test-frontend ## Run all tests
	@echo "$(GREEN)✓ All tests passed$(NC)"

test-backend: ## Run backend tests
	@echo "$(BLUE)Running backend tests...$(NC)"
	cd src/backend && pytest tests/ -v --cov=app --cov-report=html
	@echo "$(GREEN)✓ Backend tests passed$(NC)"

test-frontend: ## Run frontend tests
	@echo "$(BLUE)Running frontend tests...$(NC)"
	cd src/frontend && npm test
	@echo "$(GREEN)✓ Frontend tests passed$(NC)"

test-integration: ## Run integration tests (requires running services)
	@echo "$(BLUE)Running integration tests...$(NC)"
	cd tests && pytest integration/ -v
	@echo "$(GREEN)✓ Integration tests passed$(NC)"

test-notebooks: ## Run Jupyter notebook tests
	@echo "$(BLUE)Running notebook tests...$(NC)"
	jupyter nbconvert --to notebook --execute notebooks/e2e_test_cases.ipynb
	@echo "$(GREEN)✓ Notebook tests passed$(NC)"

## Code Quality

lint: lint-backend lint-frontend ## Run linters for backend and frontend
	@echo "$(GREEN)✓ Linting complete$(NC)"

lint-backend: ## Lint backend code
	@echo "$(BLUE)Linting backend...$(NC)"
	cd src/backend && ruff check app/ tests/
	cd src/backend && mypy app/

lint-frontend: ## Lint frontend code
	@echo "$(BLUE)Linting frontend...$(NC)"
	cd src/frontend && npm run lint

format: format-backend format-frontend ## Format code (backend + frontend)
	@echo "$(GREEN)✓ Code formatted$(NC)"

format-backend: ## Format backend code
	@echo "$(BLUE)Formatting backend...$(NC)"
	cd src/backend && black app/ tests/
	cd src/backend && isort app/ tests/

format-frontend: ## Format frontend code
	@echo "$(BLUE)Formatting frontend...$(NC)"
	cd src/frontend && npm run format

## Infrastructure

validate: ## Validate Bicep templates
	@echo "$(BLUE)Validating Bicep templates...$(NC)"
	az bicep build --file infra/bicep/main.bicep
	@echo "$(GREEN)✓ Bicep templates are valid$(NC)"

deploy: ## Deploy to Azure (usage: make deploy ENV=dev)
ifndef ENV
	$(error ENV is required. Usage: make deploy ENV=dev)
endif
	@echo "$(BLUE)Deploying to $(ENV) environment...$(NC)"
	bash infra/scripts/bootstrap.sh $(ENV)
	@echo "$(GREEN)✓ Deployment complete$(NC)"

destroy: ## Destroy Azure resources (usage: make destroy ENV=dev)
ifndef ENV
	$(error ENV is required. Usage: make destroy ENV=dev)
endif
	@echo "$(YELLOW)⚠️  WARNING: This will delete all resources in $(ENV)$(NC)"
	bash infra/scripts/cleanup.sh $(ENV)

## Monitoring

logs: ## Tail Azure App Service logs (usage: make logs ENV=dev)
ifndef ENV
	$(error ENV is required. Usage: make logs ENV=dev)
endif
	@echo "$(BLUE)Tailing logs for $(ENV)...$(NC)"
	az webapp log tail --name translator-$(ENV)-api --resource-group translator-$(ENV)-rg

logs-backend: ## View local backend logs
	docker compose logs -f backend

logs-frontend: ## View local frontend logs
	docker compose logs -f frontend

## Data and Samples

load-samples: ## Load sample data into storage
	@echo "$(BLUE)Loading sample data...$(NC)"
	cd data/ingestion && python load_samples.py
	@echo "$(GREEN)✓ Sample data loaded$(NC)"

## Utilities

clean: ## Clean build artifacts and caches
	@echo "$(BLUE)Cleaning build artifacts...$(NC)"
	find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name ".pytest_cache" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name ".ruff_cache" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name ".mypy_cache" -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete 2>/dev/null || true
	cd src/backend && rm -rf htmlcov .coverage 2>/dev/null || true
	cd src/frontend && rm -rf dist build node_modules/.cache 2>/dev/null || true
	@echo "$(GREEN)✓ Cleaned$(NC)"

clean-docker: ## Clean Docker containers, images, and volumes
	@echo "$(YELLOW)Cleaning Docker resources...$(NC)"
	docker compose down -v --remove-orphans
	docker system prune -f
	@echo "$(GREEN)✓ Docker cleaned$(NC)"

env-example: ## Create .env from env.example
	@if [ ! -f .env ]; then \
		cp env.example .env; \
		echo "$(GREEN)✓ Created .env file from env.example$(NC)"; \
		echo "$(YELLOW)⚠️  Please update .env with your Azure credentials$(NC)"; \
	else \
		echo "$(YELLOW).env file already exists$(NC)"; \
	fi

diagrams: ## Generate architecture diagrams
	@echo "$(BLUE)Generating diagrams...$(NC)"
	python docs/images/generate_diagrams.py
	@echo "$(GREEN)✓ Diagrams generated$(NC)"

## CI/CD

ci-test: ## Run CI test suite
	@echo "$(BLUE)Running CI tests...$(NC)"
	make lint
	make test
	@echo "$(GREEN)✓ CI tests passed$(NC)"

ci-build: ## Build Docker images for CI
	@echo "$(BLUE)Building Docker images...$(NC)"
	docker compose build
	@echo "$(GREEN)✓ Build complete$(NC)"

## Documentation

docs-serve: ## Serve documentation locally
	@echo "$(BLUE)Serving documentation...$(NC)"
	@echo "Open: http://localhost:8080"
	python -m http.server 8080 --directory docs

## Version

version: ## Show version information
	@echo "Azure Translator Solution Accelerator"
	@echo "Version: 1.0.0"
	@echo ""
	@echo "Backend:"
	@cd src/backend && python --version
	@echo ""
	@echo "Frontend:"
	@cd src/frontend && node --version && npm --version
	@echo ""
	@echo "Azure CLI:"
	@az --version | head -n 1
	@echo ""
	@echo "Docker:"
	@docker --version

