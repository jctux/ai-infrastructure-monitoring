# GitHub Copilot Instructions · AI Infrastructure Monitoring

**Project**: AI Infrastructure Monitoring Stack  
**Last Updated**: 2025-12-31  
**Purpose**: Production-grade monitoring and alerting with AI-powered analysis

---

## 🎯 Project Overview

This is a **standalone monitoring stack** for infrastructure and application monitoring, featuring:

- **Prometheus** - Metrics collection and time-series database
- **Alertmanager** - Alert routing and notification management
- **AI Alert Processor** - AI-powered root cause analysis via LiteLLM
- **Grafana** - Data visualization and dashboards
- **HashiCorp Vault** - Secure secrets management

---

## 🏗️ Architecture Principles

### 1. Portability First
- Deploy anywhere with Docker Compose
- No hardcoded IPs, hostnames, or credentials
- Environment-agnostic configuration

### 2. Vault-Based Secrets
- ALL secrets stored in HashiCorp Vault
- No `.env` files with credentials
- Dynamic secret retrieval at runtime

### 3. AI-Enhanced Alerting
- Automatic alert analysis with LLM
- Root cause identification
- Actionable remediation suggestions

### 4. Production-Ready
- Health checks on all services
- Data persistence via Docker volumes
- Automated deployment scripts

---

## 📂 Repository Structure

```
ai-infrastructure-monitoring/
├── ai_alert_processor/      # AI analysis service
│   ├── ai_alert_processor.py
│   ├── Dockerfile
│   └── requirements.txt
├── alerting/                 # Alertmanager configs
│   ├── alertmanager.yml
│   └── alerts.yml
├── grafana_custom/           # Grafana provisioning
│   ├── dashboards/
│   └── provisioning/
├── prometheus/               # Prometheus config
│   └── prometheus.yml
├── docs/                     # Documentation
│   └── VAULT_SETUP.md
├── docker-compose.yml        # Service orchestration
├── deploy.sh                 # Automated deployment
├── .env.example              # Vault connection template
└── README.md
```

---

## 🔐 Secrets Management

### Required Vault Secrets

All secrets must be stored in Vault at path: `ai-infrastructure-monitoring/`

| Key | Description |
|-----|-------------|
| `litellm/url` | LiteLLM proxy URL |
| `litellm/master_key` | LiteLLM authentication key |
| `litellm/model` | AI model name (e.g., gpt-4o) |
| `grafana/admin_user` | Grafana admin username |
| `grafana/admin_pass` | Grafana admin password |

### .env File

Only contains Vault connection info:
```bash
VAULT_ADDR=http://your-vault-host:8200
VAULT_TOKEN=your-vault-token
VAULT_SECRETS_PATH=ai-infrastructure-monitoring
```

---

## 🚀 Development Guidelines

### When Modifying Code

1. **Keep it Generic**
   - No hardcoded IPs, hostnames, or project names
   - Use environment variables or Vault secrets
   - Make configurations customizable

2. **Maintain Portability**
   - Test on multiple hosts if possible
   - Avoid OS-specific dependencies
   - Use Docker networking for service communication

3. **Document Changes**
   - Update README.md for user-facing changes
   - Update VAULT_SETUP.md for new secrets
   - Keep docker-compose.yml comments clear

4. **Security First**
   - Never commit secrets to git
   - Use Vault for all sensitive data
   - Validate Vault connectivity before deployment

### When Adding Features

1. **AI Alert Processor** (`ai_alert_processor/`)
   - Add new analysis logic in `ai_alert_processor.py`
   - Update prompt engineering for better results
   - Test with various alert scenarios

2. **Prometheus** (`prometheus/`)
   - Add example scrape configs (commented out)
   - Keep alert rules generic and reusable
   - Document metric naming conventions

3. **Grafana** (`grafana_custom/`)
   - Export dashboards as JSON
   - Use provisioning for datasources
   - Include dashboard descriptions

4. **Documentation** (`docs/`, `README.md`)
   - Provide step-by-step instructions
   - Include troubleshooting sections
   - Add architecture diagrams if helpful

---

## 🔧 Common Operations

### Local Development

```bash
# Clone repository
git clone https://github.com/jctux/ai-infrastructure-monitoring.git
cd ai-infrastructure-monitoring

# Configure environment
cp .env.example .env
# Edit .env with your Vault details

# Deploy
./deploy.sh
```

### Testing Changes

```bash
# Rebuild and restart
docker-compose build
docker-compose up -d

# View logs
docker-compose logs -f ai-alert-processor

# Test AI processor
curl http://localhost:5050/health
```

### Updating Documentation

```bash
# Edit documentation
vim README.md
vim docs/VAULT_SETUP.md

# Commit changes
git add .
git commit -m "docs: update deployment instructions"
git push origin main
```

---

## 📊 Monitoring Targets

This stack can monitor:

- **Infrastructure**: CPU, memory, disk, network metrics
- **Applications**: Custom application metrics via /metrics endpoint
- **Databases**: PostgreSQL, MySQL, Redis exporters
- **Containers**: Docker metrics via cAdvisor
- **GPU Workloads**: NVIDIA GPU metrics via DCGM exporter
- **Web Services**: Blackbox exporter for HTTP/HTTPS probes

---

## 🛠️ Tech Stack

| Component | Technology | Version |
|-----------|-----------|---------|
| Metrics | Prometheus | latest |
| Alerting | Alertmanager | latest |
| AI Analysis | FastAPI + LiteLLM | latest |
| Visualization | Grafana | latest |
| Secrets | HashiCorp Vault | - |
| Container Runtime | Docker | - |

---

## 🎯 Key Design Decisions

### 1. Why Vault?
- Centralized secret management
- Dynamic credentials
- Audit logging
- Access control policies

### 2. Why LiteLLM?
- Unified interface for multiple LLM providers
- Built-in caching and rate limiting
- Proxy pattern for cost control
- OpenAI-compatible API

### 3. Why Docker Compose?
- Simple single-host deployment
- Easy to understand and modify
- No Kubernetes complexity
- Perfect for SMB infrastructure

### 4. Why AI Alert Analysis?
- Reduces MTTR (Mean Time To Resolution)
- Provides context-aware suggestions
- Helps junior engineers
- Documents incident patterns

---

## 🚨 Important Notes

### DO:
- Use Vault for all secrets
- Keep configurations generic
- Document architectural decisions
- Test deployment script changes
- Update version compatibility

### DON'T:
- Hardcode IPs or hostnames (except examples)
- Commit secrets or .env files
- Add project-specific configurations
- Break Docker Compose compatibility
- Modify without testing

---

## 📚 Additional Resources

- **Prometheus Docs**: https://prometheus.io/docs/
- **Grafana Docs**: https://grafana.com/docs/
- **Alertmanager Docs**: https://prometheus.io/docs/alerting/latest/alertmanager/
- **Vault Docs**: https://www.vaultproject.io/docs
- **LiteLLM Docs**: https://docs.litellm.ai/

---

## 🤝 Contributing

When contributing:
1. Fork the repository
2. Create a feature branch
3. Test thoroughly
4. Update documentation
5. Submit pull request

---

**Questions?** Open an issue at: https://github.com/jctux/ai-infrastructure-monitoring/issues
