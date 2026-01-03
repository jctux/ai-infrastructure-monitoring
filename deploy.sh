#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Remote host configuration
REMOTE_HOST="10.1.0.99"
REMOTE_USER="jc"
REMOTE_PATH="~/ai-infrastructure-monitoring"
REMOTE_BRANCH="main"

echo -e "${BLUE}🚀 Deployment Script - AI Infrastructure Monitoring${NC}"
echo "========================================================="
echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
echo "Target: ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}"
echo "Branch: ${REMOTE_BRANCH}"
echo ""

# Parse arguments
SKIP_BUILD=false
QUICK_MODE=false
CHECK_EXTERNAL=true
FORCE_SYNC=false
TEST_SMS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        --quick)
            QUICK_MODE=true
            shift
            ;;
        --skip-external-check)
            CHECK_EXTERNAL=false
            shift
            ;;
        --force-sync)
            FORCE_SYNC=true
            shift
            ;;
        --test-sms)
            TEST_SMS=true
            shift
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Usage: $0 [--skip-build] [--quick] [--skip-external-check] [--force-sync] [--test-sms]"
            echo ""
            echo "Options:"
            echo "  --skip-build          Skip Docker image rebuild"
            echo "  --quick              Quick mode: skip cleanup and cache"
            echo "  --skip-external-check Skip external services health check"
            echo "  --force-sync         Force file sync even with uncommitted changes"
            echo "  --test-sms           Send test SMS after deployment"
            exit 1
            ;;
    esac
done

echo -e "${YELLOW}📋 Pre-deployment checks...${NC}"

# Check if SSH connection works
if ! ssh -o BatchMode=yes -o ConnectTimeout=5 ${REMOTE_USER}@${REMOTE_HOST} exit &> /dev/null; then
    echo -e "${RED}❌ Cannot connect to ${REMOTE_USER}@${REMOTE_HOST}${NC}"
    echo "Please ensure SSH key authentication is set up"
    exit 1
fi

echo -e "${GREEN}✅ SSH connection to remote host OK${NC}"

# Check if we're on the correct branch locally
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
if [ "$CURRENT_BRANCH" != "$REMOTE_BRANCH" ] && [ "$CURRENT_BRANCH" != "unknown" ]; then
    echo -e "${YELLOW}⚠️  Warning: Current branch is '${CURRENT_BRANCH}', but deploying '${REMOTE_BRANCH}'${NC}"
fi

# Check for uncommitted changes
if [ "$FORCE_SYNC" = false ]; then
    if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
        echo -e "${RED}❌ You have uncommitted changes${NC}"
        echo "Please commit or stash your changes before deploying"
        echo "Or use --force-sync to deploy anyway"
        git status --short
        exit 1
    fi
    echo -e "${GREEN}✅ Git repository is clean${NC}"
else
    echo -e "${YELLOW}⚠️  Force sync mode - deploying with uncommitted changes${NC}"
fi

# Check external services health
if [ "$CHECK_EXTERNAL" = true ]; then
    echo -e "${YELLOW}🔍 Checking external services...${NC}"
    
    # Check LiteLLM
    if ssh ${REMOTE_USER}@${REMOTE_HOST} "curl -s http://10.1.0.99:4000/health" > /dev/null 2>&1; then
        echo -e "${GREEN}  ✅ LiteLLM is ready (10.1.0.99:4000)${NC}"
    else
        echo -e "${YELLOW}  ⚠️  LiteLLM health check failed${NC}"
        echo -e "${YELLOW}  Continuing anyway... (AI analysis may not work)${NC}"
    fi
    
    # Check Vault
    if ssh ${REMOTE_USER}@${REMOTE_HOST} "curl -s http://10.1.0.99:8200/v1/sys/health" > /dev/null 2>&1; then
        echo -e "${GREEN}  ✅ Vault is ready (10.1.0.99:8200)${NC}"
    else
        echo -e "${RED}  ❌ Vault is not accessible${NC}"
        echo "Make sure Vault is running on 10.1.0.99:8200"
        exit 1
    fi
fi

# Sync code to remote
echo -e "${YELLOW}📦 Syncing code to production...${NC}"

if [ "$FORCE_SYNC" = true ]; then
    # Force sync using rsync
    echo -e "${BLUE}ℹ️  Using rsync for force sync...${NC}"
    
    rsync -avz --progress \
        --exclude='.git/' \
        --exclude='__pycache__/' \
        --exclude='*.pyc' \
        --exclude='node_modules/' \
        --exclude='.venv/' \
        --exclude='venv/' \
        --exclude='.pytest_cache/' \
        --exclude='*.log' \
        --exclude='.DS_Store' \
        . ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}/
        
    echo -e "${GREEN}✅ Code synced via rsync${NC}"
else
    # Check if remote directory exists and is a git repo
    if ssh ${REMOTE_USER}@${REMOTE_HOST} "[ -d ${REMOTE_PATH}/.git ]"; then
        echo -e "${BLUE}ℹ️  Remote repository exists, pulling latest changes...${NC}"
        
        # Reset any local changes and pull
        ssh ${REMOTE_USER}@${REMOTE_HOST} "cd ${REMOTE_PATH} && git reset --hard && git clean -fd && git fetch origin ${REMOTE_BRANCH} && git reset --hard origin/${REMOTE_BRANCH}"
        
        if [ $? -ne 0 ]; then
            echo -e "${RED}❌ Git pull failed${NC}"
            echo "Use --force-sync to sync files directly"
            exit 1
        fi
    else
        echo -e "${BLUE}ℹ️  Cloning repository to remote server...${NC}"
        
        # Get the remote URL
        GIT_REMOTE=$(git config --get remote.origin.url 2>/dev/null || echo "")
        
        if [ -z "$GIT_REMOTE" ]; then
            echo -e "${RED}❌ Not a git repository${NC}"
            echo "Use --force-sync to sync files directly"
            exit 1
        fi
        
        # Clone the repository
        ssh ${REMOTE_USER}@${REMOTE_HOST} "mkdir -p $(dirname ${REMOTE_PATH}) && git clone -b ${REMOTE_BRANCH} ${GIT_REMOTE} ${REMOTE_PATH}"
    fi
    
    echo -e "${GREEN}✅ Code synced successfully via Git${NC}"
fi

# Ensure .env file exists on remote
echo -e "${YELLOW}🔧 Configuring environment on remote...${NC}"

if [ -f .env ]; then
    echo -e "${BLUE}ℹ️  Copying .env to remote...${NC}"
    scp .env ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}/.env
    echo -e "${GREEN}✅ .env copied to remote${NC}"
else
    echo -e "${YELLOW}⚠️  No local .env file found${NC}"
    
    # Check if .env exists on remote
    if ! ssh ${REMOTE_USER}@${REMOTE_HOST} "[ -f ${REMOTE_PATH}/.env ]"; then
        echo -e "${RED}❌ No .env file on remote either${NC}"
        echo "Creating default .env on remote..."
        
        ssh ${REMOTE_USER}@${REMOTE_HOST} "cat > ${REMOTE_PATH}/.env << 'ENVEOF'
VAULT_ADDR=http://10.1.0.99:8200
VAULT_TOKEN=your-vault-token-here
VAULT_SECRETS_PATH=ai-infrastructure-monitoring
ENVEOF"
        
        echo -e "${YELLOW}⚠️  IMPORTANT: Update VAULT_TOKEN in ${REMOTE_PATH}/.env on remote server${NC}"
        echo -e "${GREEN}✅ Created default .env on remote${NC}"
    else
        echo -e "${GREEN}✅ Using existing .env on remote${NC}"
    fi
fi

# Fix Dockerfile
echo -e "${YELLOW}🔧 Fixing Dockerfile...${NC}"
ssh ${REMOTE_USER}@${REMOTE_HOST} "sed -i 's/main.py/ai_alert_processor.py/g' ${REMOTE_PATH}/ai_alert_processor/Dockerfile"
echo -e "${GREEN}✅ Dockerfile fixed${NC}"

# Build production images on remote
if [ "$SKIP_BUILD" = false ]; then
    echo -e "${YELLOW}🔨 Building production images on remote...${NC}"
    
    if [ "$QUICK_MODE" = true ]; then
        ssh ${REMOTE_USER}@${REMOTE_HOST} "cd ${REMOTE_PATH} && docker compose build ai-alert-processor"
    else
        ssh ${REMOTE_USER}@${REMOTE_HOST} "cd ${REMOTE_PATH} && docker compose build --no-cache ai-alert-processor"
    fi
    
    echo -e "${GREEN}✅ Build completed${NC}"
else
    echo -e "${YELLOW}⏭️  Skipping build (--skip-build flag)${NC}"
fi

# Start/Restart containers
echo -e "${YELLOW}🔄 Starting/Restarting production containers...${NC}"

ssh ${REMOTE_USER}@${REMOTE_HOST} "cd ${REMOTE_PATH} && docker compose up -d"

# Wait for services to be healthy
echo -e "${YELLOW}⏳ Waiting for services to be ready...${NC}"

# Wait up to 60 seconds for health check
TIMEOUT=60
ELAPSED=0
HEALTH_CHECK_PASSED=false

while [ $ELAPSED -lt $TIMEOUT ]; do
    # Check if AI processor is responding
    if ssh ${REMOTE_USER}@${REMOTE_HOST} "curl -s http://localhost:5050/health" > /dev/null 2>&1; then
        HEALTH_CHECK_PASSED=true
        break
    fi
    sleep 2
    ELAPSED=$((ELAPSED + 2))
    echo -n "."
done

echo ""

if [ "$HEALTH_CHECK_PASSED" = true ]; then
    echo -e "${GREEN}✅ AI Alert Processor is healthy!${NC}"
else
    echo -e "${YELLOW}⚠️  Health check timed out, checking logs...${NC}"
    echo -e "${YELLOW}Last 30 lines of ai-alert-processor logs:${NC}"
    ssh ${REMOTE_USER}@${REMOTE_HOST} "cd ${REMOTE_PATH} && docker compose logs --tail=30 ai-alert-processor"
    echo ""
    echo -e "${YELLOW}Deployment completed but health check failed. Review logs above.${NC}"
fi

# Show status
echo ""
echo -e "${GREEN}✅ Deployment completed!${NC}"
echo "========================================================="
echo ""
echo -e "${BLUE}📊 Container Status on ${REMOTE_HOST}:${NC}"
ssh ${REMOTE_USER}@${REMOTE_HOST} "cd ${REMOTE_PATH} && docker compose ps"
echo ""

# Test SMS if requested
if [ "$TEST_SMS" = true ]; then
    echo -e "${BLUE}📱 Sending test SMS...${NC}"
    
    # Create a test alert payload
    TEST_PAYLOAD='{"alerts":[{"status":"firing","labels":{"alertname":"TestAlert","severity":"info"},"annotations":{"summary":"Test SMS notification from AI Infrastructure Monitoring"},"startsAt":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'","generatorURL":"http://test"}]}'
    
    # Send test alert to AI processor
    if ssh ${REMOTE_USER}@${REMOTE_HOST} "curl -s -X POST http://localhost:5050/webhook -H 'Content-Type: application/json' -d '${TEST_PAYLOAD}'" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Test alert sent! Check your phone: +528184665595${NC}"
        echo -e "${YELLOW}   You should receive 2 SMS messages:${NC}"
        echo -e "${YELLOW}   1. Alert received notification${NC}"
        echo -e "${YELLOW}   2. AI analysis result${NC}"
    else
        echo -e "${RED}❌ Failed to send test alert${NC}"
    fi
    echo ""
fi

echo -e "${BLUE}🌐 Application URLs:${NC}"
echo "   • Grafana: http://10.1.0.99:3030"
echo "   • Prometheus: http://10.1.0.99:9090"
echo "   • Alertmanager: http://10.1.0.99:9093"
echo "   • AI Processor: http://10.1.0.99:5050"
echo ""
echo -e "${BLUE}🔐 External Services:${NC}"
echo "   • LiteLLM: http://10.1.0.99:4000"
echo "   • Vault: http://10.1.0.99:8200"
echo ""
echo -e "${BLUE}📱 SMS Notifications:${NC}"
echo "   • Your number: +528184665595"
echo "   • Twilio number: +16402437900"
echo ""
echo -e "${BLUE}📝 Useful Commands:${NC}"
echo "   • View logs: ssh ${REMOTE_USER}@${REMOTE_HOST} 'cd ${REMOTE_PATH} && docker compose logs -f ai-alert-processor'"
echo "   • Check Twilio: ssh ${REMOTE_USER}@${REMOTE_HOST} 'cd ${REMOTE_PATH} && docker compose logs ai-alert-processor | grep -i twilio'"
echo "   • Restart: ssh ${REMOTE_USER}@${REMOTE_HOST} 'cd ${REMOTE_PATH} && docker compose restart'"
echo "   • Test SMS: ./deploy.sh --test-sms --skip-build"
echo "   • SSH: ssh ${REMOTE_USER}@${REMOTE_HOST}"
echo ""
echo -e "${BLUE}🔄 Next Steps:${NC}"
echo "   1. Test SMS: ./deploy.sh --test-sms --skip-build"
echo "   2. Check Grafana dashboards: http://10.1.0.99:3030"
echo "   3. Configure Prometheus targets in prometheus/prometheus.yml"
echo "   4. Set up alert rules in alerting/alerts.yml"
echo ""
