#!/bin/bash
set -e

# AI Infrastructure Monitoring - Deployment Script
# This script automates the deployment of the monitoring stack

echo "🚀 AI Infrastructure Monitoring - Deployment Script"
echo "=================================================="
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if .env exists
if [ ! -f .env ]; then
    echo -e "${RED}❌ Error: .env file not found${NC}"
    echo "Please create .env from .env.example and configure your Vault connection"
    echo ""
    echo "  cp .env.example .env"
    echo "  # Edit .env with your Vault details"
    echo ""
    exit 1
fi

# Source .env
source .env

# Validate required environment variables
if [ -z "$VAULT_ADDR" ] || [ -z "$VAULT_TOKEN" ]; then
    echo -e "${RED}❌ Error: VAULT_ADDR and VAULT_TOKEN must be set in .env${NC}"
    exit 1
fi

echo "✅ Environment configuration loaded"
echo "   VAULT_ADDR: $VAULT_ADDR"
echo "   VAULT_SECRETS_PATH: ${VAULT_SECRETS_PATH:-ai-infrastructure-monitoring}"
echo ""

# Test Vault connectivity
echo "🔐 Testing Vault connectivity..."
if curl -s -H "X-Vault-Token: $VAULT_TOKEN" "$VAULT_ADDR/v1/sys/health" > /dev/null; then
    echo -e "${GREEN}✅ Vault connection successful${NC}"
else
    echo -e "${RED}❌ Error: Cannot connect to Vault at $VAULT_ADDR${NC}"
    echo "Please check your VAULT_ADDR and VAULT_TOKEN in .env"
    exit 1
fi

# Check if secrets exist in Vault
echo ""
echo "🔍 Checking Vault secrets..."
SECRETS_PATH="${VAULT_SECRETS_PATH:-ai-infrastructure-monitoring}"

if curl -s -H "X-Vault-Token: $VAULT_TOKEN" \
    "$VAULT_ADDR/v1/secret/data/$SECRETS_PATH" | grep -q '"data"'; then
    echo -e "${GREEN}✅ Secrets found at path: $SECRETS_PATH${NC}"
else
    echo -e "${YELLOW}⚠️  Warning: Secrets not found at path: $SECRETS_PATH${NC}"
    echo "Please set up secrets in Vault. See docs/VAULT_SETUP.md"
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check if Docker is running
echo ""
echo "🐳 Checking Docker..."
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}❌ Error: Docker is not running${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Docker is running${NC}"

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null; then
    echo -e "${YELLOW}⚠️  docker-compose not found, using 'docker compose' instead${NC}"
    DOCKER_COMPOSE="docker compose"
else
    DOCKER_COMPOSE="docker-compose"
fi

# Stop existing containers
echo ""
echo "🛑 Stopping existing containers..."
$DOCKER_COMPOSE down 2>/dev/null || true
echo -e "${GREEN}✅ Stopped existing containers${NC}"

# Pull latest images
echo ""
echo "📥 Pulling latest images..."
$DOCKER_COMPOSE pull
echo -e "${GREEN}✅ Images pulled${NC}"

# Build custom images
echo ""
echo "🔨 Building AI Alert Processor..."
$DOCKER_COMPOSE build
echo -e "${GREEN}✅ Build complete${NC}"

# Start services
echo ""
echo "🚀 Starting monitoring stack..."
$DOCKER_COMPOSE up -d
echo -e "${GREEN}✅ Services started${NC}"

# Wait for services to be healthy
echo ""
echo "⏳ Waiting for services to be ready..."
sleep 5

# Check service health
echo ""
echo "🏥 Checking service health..."

check_service() {
    local name=$1
    local url=$2
    local max_attempts=30
    local attempt=1
    
    echo -n "   Checking $name..."
    while [ $attempt -le $max_attempts ]; do
        if curl -s "$url" > /dev/null 2>&1; then
            echo -e " ${GREEN}✅${NC}"
            return 0
        fi
        sleep 1
        attempt=$((attempt + 1))
    done
    echo -e " ${RED}❌ (timeout)${NC}"
    return 1
}

HEALTH_OK=true
check_service "Prometheus" "http://localhost:9090/-/healthy" || HEALTH_OK=false
check_service "Alertmanager" "http://localhost:9093/-/healthy" || HEALTH_OK=false
check_service "AI Processor" "http://localhost:5050/health" || HEALTH_OK=false
check_service "Grafana" "http://localhost:3030/api/health" || HEALTH_OK=false

echo ""
if [ "$HEALTH_OK" = true ]; then
    echo -e "${GREEN}✅ All services are healthy${NC}"
else
    echo -e "${YELLOW}⚠️  Some services may not be fully ready yet${NC}"
    echo "Check logs with: $DOCKER_COMPOSE logs -f"
fi

# Display service URLs
echo ""
echo "=================================================="
echo "🎉 Deployment Complete!"
echo "=================================================="
echo ""
echo "Access your services:"
echo "  📊 Grafana:          http://localhost:3030"
echo "  📈 Prometheus:       http://localhost:9090"
echo "  🔔 Alertmanager:     http://localhost:9093"
echo "  🤖 AI Processor:     http://localhost:5050"
echo ""
echo "Useful commands:"
echo "  View logs:           $DOCKER_COMPOSE logs -f"
echo "  View logs (service): $DOCKER_COMPOSE logs -f <service>"
echo "  Stop stack:          $DOCKER_COMPOSE down"
echo "  Restart stack:       $DOCKER_COMPOSE restart"
echo "  Update stack:        git pull && $DOCKER_COMPOSE up -d --build"
echo ""
echo "For Grafana login credentials, check your Vault secrets."
echo ""
