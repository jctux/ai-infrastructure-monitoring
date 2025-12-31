# AI Infrastructure Monitoring Stack

Production-grade monitoring and alerting system with AI-powered alert analysis using LiteLLM, Prometheus, Grafana, and HashiCorp Vault for secrets management.

## Overview

This standalone monitoring stack provides:
- **Prometheus** - Metrics collection and time-series database
- **Alertmanager** - Alert routing and management
- **AI Alert Processor** - AI-powered alert analysis using LiteLLM
- **Grafana** - Visualization and dashboards
- **HashiCorp Vault** - Secure secrets management

## Features

- **AI-Powered Alerts**: Automatic root cause analysis and remediation suggestions
- **Secure by Default**: All secrets stored in Vault, no hardcoded credentials
- **Portable**: Deploy anywhere with Docker Compose
- **Production Ready**: Includes data persistence, health checks, and proper restart policies
- **Pre-configured Dashboards**: Ready-to-use Grafana dashboards for infrastructure monitoring

## Architecture

```
┌─────────────────┐
│   Prometheus    │──> Scrapes metrics from targets
│    :9090        │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Alertmanager   │──> Routes alerts to AI processor
│    :9093        │
└────────┬────────┘
         │
         ▼
┌─────────────────┐      ┌──────────────┐
│ AI Alert        │─────>│  LiteLLM     │
│ Processor       │      │  Proxy       │
│    :5050        │<─────│  :4000       │
└─────────────────┘      └──────────────┘
         │
         ▼
┌─────────────────┐
│    Grafana      │──> Visualizes metrics
│    :3030        │
└─────────────────┘
         │
         ▼
┌─────────────────┐
│  HashiCorp      │──> Manages secrets
│    Vault        │
│    :8200        │
└─────────────────┘
```

## Prerequisites

- Docker & Docker Compose
- Access to a HashiCorp Vault instance
- Access to a LiteLLM proxy instance
- Vault token with read permissions to secrets path

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/jctux/ai-infrastructure-monitoring.git
cd ai-infrastructure-monitoring
```

### 2. Configure Environment

```bash
cp .env.example .env
# Edit .env with your Vault connection details
```

### 3. Set Up Vault Secrets

See [VAULT_SETUP.md](docs/VAULT_SETUP.md) for detailed instructions.

Required secrets in Vault at path `ai-infrastructure-monitoring/`:

```
litellm/url          -> http://your-litellm-host:4000
litellm/master_key   -> your-litellm-master-key
litellm/model        -> gpt-4o
grafana/admin_user   -> admin
grafana/admin_pass   -> secure-password
```

### 4. Configure Prometheus Targets

Edit `prometheus/prometheus.yml` to add your scrape targets:

```yaml
scrape_configs:
  - job_name: 'your-service'
    static_configs:
      - targets: ['your-host:port']
```

### 5. Deploy

```bash
docker-compose up -d
```

### 6. Access Services

- **Grafana**: http://localhost:3030
- **Prometheus**: http://localhost:9090
- **Alertmanager**: http://localhost:9093
- **AI Alert Processor**: http://localhost:5050

## Configuration

### Prometheus

Edit `prometheus/prometheus.yml` to:
- Add scrape targets for your services
- Configure scrape intervals
- Set up service discovery

### Alertmanager

Edit `alerting/alertmanager.yml` to:
- Configure notification routes
- Set up receivers (email, Slack, etc.)
- Adjust grouping and timing

### Alert Rules

Edit `alerting/alerts.yml` to:
- Add custom alert rules
- Adjust thresholds
- Define severity levels

### Grafana Dashboards

Pre-configured dashboards are in `grafana_custom/dashboards/`. You can:
- Import additional dashboards from Grafana.com
- Create custom dashboards via the UI
- Export and commit new dashboards to the repo

## Vault Integration

This stack uses HashiCorp Vault for secrets management. Benefits:

- **Centralized Secrets**: All secrets in one secure location
- **Dynamic Secrets**: Rotate credentials without redeployment
- **Audit Trail**: Track all secret access
- **Access Control**: Fine-grained permissions

See [docs/VAULT_SETUP.md](docs/VAULT_SETUP.md) for setup instructions.

## AI Alert Analysis

The AI Alert Processor analyzes incoming alerts and provides:

1. **Severity Assessment** - Low/Medium/High/Critical classification
2. **Root Cause Analysis** - Probable causes based on alert context
3. **Remediation Steps** - Actionable recommendations for resolution

### Example Analysis

```
Alert: High CPU usage on production-server-01

AI Analysis:
Severity: HIGH
Root Cause: Runaway process consuming 95% CPU, likely due to infinite loop
Remediation:
1. Identify process with `top` or `htop`
2. Investigate process logs for errors
3. Kill process if necessary: `kill -9 <PID>`
4. Review application code for infinite loops
5. Consider adding resource limits to prevent future occurrences
```

## Monitoring Targets

Configure Prometheus to scrape metrics from:

- **Applications**: Export custom metrics via /metrics endpoint
- **Databases**: PostgreSQL, MySQL, Redis exporters
- **Infrastructure**: Node exporter for system metrics
- **GPU Workloads**: DCGM exporter for NVIDIA GPUs
- **Containers**: cAdvisor for Docker metrics

## Ports

| Service | Port | Description |
|---------|------|-------------|
| Prometheus | 9090 | Metrics and PromQL queries |
| Alertmanager | 9093 | Alert management UI |
| AI Processor | 5050 | Webhook endpoint and health |
| Grafana | 3030 | Dashboards and visualization |

## Data Persistence

All data is persisted in Docker volumes:

- `prometheus-data` - Metrics time-series data (30 days retention)
- `alertmanager-data` - Alert state and silences
- `grafana-data` - Dashboards, users, and settings

## Upgrading

```bash
# Pull latest changes
git pull origin main

# Rebuild containers
docker-compose build --pull

# Restart services
docker-compose up -d
```

## Troubleshooting

### Vault Connection Issues

```bash
# Test Vault connectivity
curl -H "X-Vault-Token: $VAULT_TOKEN" $VAULT_ADDR/v1/sys/health

# Verify secret exists
vault kv get ai-infrastructure-monitoring
```

### AI Processor Not Working

```bash
# Check logs
docker logs ai-alert-processor

# Verify LiteLLM connectivity
docker exec ai-alert-processor curl -H "Authorization: Bearer $LITELLM_KEY" $LITELLM_URL/health
```

### Prometheus Not Scraping

```bash
# Check Prometheus targets
curl http://localhost:9090/api/v1/targets

# Verify network connectivity
docker exec monitoring-prometheus ping your-target-host
```

## Security Considerations

- **Vault Tokens**: Use time-limited tokens with minimum required permissions
- **Network Isolation**: Deploy in private network, use reverse proxy for external access
- **TLS**: Enable TLS for production deployments
- **Grafana**: Change default admin password immediately
- **Firewall**: Restrict access to monitoring ports

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

MIT License - See LICENSE file for details

## Support

For issues and questions:
- GitHub Issues: https://github.com/jctux/ai-infrastructure-monitoring/issues
- Documentation: [docs/](docs/)

## Roadmap

- [ ] Multi-tenant support with separate Grafana organizations
- [ ] Slack/Teams integration for AI analysis results
- [ ] Custom alert templates with Jinja2
- [ ] Automated remediation workflows
- [ ] Machine learning-based anomaly detection
- [ ] High availability setup with multiple replicas

## Acknowledgments

Built with:
- [Prometheus](https://prometheus.io/)
- [Grafana](https://grafana.com/)
- [Alertmanager](https://prometheus.io/docs/alerting/latest/alertmanager/)
- [LiteLLM](https://github.com/BerriAI/litellm)
- [HashiCorp Vault](https://www.vaultproject.io/)
