# HashiCorp Vault Setup Guide

This guide explains how to configure HashiCorp Vault to store secrets for the AI Infrastructure Monitoring Stack.

## Prerequisites

- HashiCorp Vault server running and accessible
- Vault CLI installed (optional, for command-line operations)
- Vault token with appropriate permissions

## Secrets Structure

The monitoring stack requires secrets to be stored at a specific path in Vault's KV v2 secrets engine.

### Default Path

```
ai-infrastructure-monitoring/
├── litellm/url           # LiteLLM proxy URL
├── litellm/master_key    # LiteLLM authentication key
├── litellm/model         # AI model to use (e.g., gpt-4o)
├── grafana/admin_user    # Grafana admin username
├── grafana/admin_pass    # Grafana admin password
├── twilio/account_sid    # Twilio Account SID
├── twilio/auth_token     # Twilio Auth Token
├── twilio/phone_from     # Twilio phone number (format: +1234567890)
└── twilio/phone_to       # Your phone number for alerts (format: +1234567890)
```

## Setup Methods

### Method 1: Using Vault CLI

#### 1. Login to Vault

```bash
export VAULT_ADDR="http://10.1.0.99:8200"
vault login
# Enter your token when prompted
```

#### 2. Enable KV v2 Secrets Engine (if not already enabled)

```bash
vault secrets enable -version=2 -path=secret kv
```

#### 3. Write Secrets

```bash
# LiteLLM Configuration
vault kv put secret/ai-infrastructure-monitoring \
  litellm/url="http://10.1.0.99:4000" \
  litellm/master_key="your-litellm-master-key" \
  litellm/model="gpt-4o" \
  grafana/admin_user="admin" \
  grafana/admin_pass="your-secure-password" \
  twilio/account_sid="your-twilio-account-sid" \
  twilio/auth_token="your-twilio-auth-token" \
  twilio/phone_from="+1234567890" \
  twilio/phone_to="+1234567890"
```

#### 4. Verify Secrets

```bash
vault kv get secret/ai-infrastructure-monitoring
```

### Method 2: Using Vault UI

#### 1. Access Vault UI

Navigate to your Vault instance (e.g., `http://10.1.0.99:8200/ui`)

#### 2. Navigate to Secrets

- Click on "secret/" in the left sidebar
- Click "Create secret"

#### 3. Create Secret Path

Set the path to: `ai-infrastructure-monitoring`

#### 4. Add Key-Value Pairs

Add the following secrets:

| Key | Value |
|-----|-------|
| `litellm/url` | `http://10.1.0.99:4000` |
| `litellm/master_key` | Your LiteLLM master key |
| `litellm/model` | `gpt-4o` |
| `grafana/admin_user` | `admin` |
| `grafana/admin_pass` | Your secure Grafana password |
| `twilio/account_sid` | Your Twilio Account SID |
| `twilio/auth_token` | Your Twilio Auth Token |
| `twilio/phone_from` | `+1234567890` |
| `twilio/phone_to` | `+1234567890` |

#### 5. Save

Click "Save" to store the secrets.

### Method 3: Using Python Script

Create a file `setup_vault_secrets.py`:

```python
#!/usr/bin/env python3
import hvac
import os

# Configuration
VAULT_ADDR = os.getenv("VAULT_ADDR", "http://10.1.0.99:8200")
VAULT_TOKEN = os.getenv("VAULT_TOKEN")
SECRETS_PATH = "ai-infrastructure-monitoring"

# Connect to Vault
client = hvac.Client(url=VAULT_ADDR, token=VAULT_TOKEN)

if not client.is_authenticated():
    print("ERROR: Failed to authenticate with Vault")
    exit(1)

# Define secrets
secrets = {
    "litellm/url": "http://10.1.0.99:4000",
    "litellm/master_key": "your-litellm-master-key",  # CHANGE THIS
    "litellm/model": "gpt-4o",
    "grafana/admin_user": "admin",
    "grafana/admin_pass": "your-secure-password",  # CHANGE THIS
    "twilio/account_sid": "your-twilio-account-sid",  # CHANGE THIS
    "twilio/auth_token": "your-twilio-auth-token",  # CHANGE THIS
    "twilio/phone_from": "+1234567890",  # CHANGE THIS
    "twilio/phone_to": "+1234567890"  # CHANGE THIS
}

# Write secrets to Vault
try:
    client.secrets.kv.v2.create_or_update_secret(
        path=SECRETS_PATH,
        secret=secrets
    )
    print(f"✅ Secrets written to {SECRETS_PATH}")
    
    # Verify
    secret = client.secrets.kv.v2.read_secret_version(path=SECRETS_PATH)
    print(f"✅ Verification successful. Found {len(secret['data']['data'])} secrets")
    
except Exception as e:
    print(f"❌ Error: {e}")
    exit(1)
```

Run the script:

```bash
export VAULT_ADDR="http://10.1.0.99:8200"
export VAULT_TOKEN="your-vault-token"
python3 setup_vault_secrets.py
```

## Vault Token Creation

### Create a Dedicated Token for Monitoring

For production use, create a token with limited permissions:

#### 1. Create a Policy

```bash
vault policy write monitoring-read - <<EOF
path "secret/data/ai-infrastructure-monitoring" {
  capabilities = ["read"]
}
EOF
```

#### 2. Generate Token with Policy

```bash
vault token create -policy=monitoring-read -ttl=720h
```

Save the generated token and use it in your `.env` file.

### Token Properties

- **TTL**: Set appropriate time-to-live (e.g., 30 days)
- **Renewable**: Make token renewable for long-running services
- **Orphan**: Consider orphan tokens to prevent revocation cascades

Example with more options:

```bash
vault token create \
  -policy=monitoring-read \
  -ttl=720h \
  -renewable=true \
  -display-name="ai-monitoring-stack"
```

## Environment Configuration

### 1. Copy Environment Template

```bash
cp .env.example .env
```

### 2. Edit .env File

```bash
# Vault Connection Configuration
VAULT_ADDR=http://10.1.0.99:8200
VAULT_TOKEN=hvs.XXXXXXXXXXXXXXXXXXXXX
VAULT_SECRETS_PATH=ai-infrastructure-monitoring
```

### 3. Secure the .env File

```bash
chmod 600 .env
```

## Updating Secrets

### Update Specific Secret

```bash
# Read current secrets
vault kv get -format=json secret/ai-infrastructure-monitoring > current.json

# Update specific value
vault kv patch secret/ai-infrastructure-monitoring \
  litellm/master_key="new-master-key"
```

### Rotate All Secrets

```bash
vault kv put secret/ai-infrastructure-monitoring \
  litellm/url="http://10.1.0.99:4000" \
  litellm/master_key="new-litellm-key" \
  litellm/model="gpt-4o" \
  grafana/admin_user="admin" \
  grafana/admin_pass="new-secure-password" \
  twilio/account_sid="your-twilio-account-sid" \
  twilio/auth_token="your-twilio-auth-token" \
  twilio/phone_from="+1234567890" \
  twilio/phone_to="+1234567890"

# Restart monitoring stack to pick up new secrets
docker-compose restart
```

## Security Best Practices

### 1. Token Management

- Use time-limited tokens with appropriate TTL
- Rotate tokens regularly
- Use the minimum required permissions
- Never commit tokens to version control

### 2. Secret Rotation

- Rotate secrets periodically (e.g., every 90 days)
- Update secrets in Vault first, then restart services
- Maintain an emergency rotation procedure

### 3. Access Control

- Use Vault policies to restrict secret access
- Enable audit logging in Vault
- Monitor Vault access logs for anomalies

### 4. Network Security

- Use TLS for Vault communication in production
- Restrict Vault network access with firewall rules
- Consider using Vault namespaces for multi-tenancy

## Troubleshooting

### Authentication Failed

```bash
# Verify token is valid
vault token lookup

# Check token capabilities
vault token capabilities secret/data/ai-infrastructure-monitoring
```

### Secrets Not Found

```bash
# List secrets at path
vault kv list secret/

# Check exact path
vault kv get secret/ai-infrastructure-monitoring
```

### Connection Issues

```bash
# Test Vault connectivity
curl -H "X-Vault-Token: $VAULT_TOKEN" \
  $VAULT_ADDR/v1/sys/health

# Check Vault status
vault status
```

### Permission Denied

```bash
# Check token policies
vault token lookup -format=json | jq .data.policies

# Verify policy allows read access
vault policy read monitoring-read
```

## Vault Backup

### Export Secrets (for backup)

```bash
# Export secrets to encrypted file
vault kv get -format=json secret/ai-infrastructure-monitoring | \
  gpg --encrypt --recipient your@email.com > secrets.gpg
```

### Restore Secrets

```bash
# Decrypt and restore
gpg --decrypt secrets.gpg | \
  jq -r '.data.data' | \
  vault kv put secret/ai-infrastructure-monitoring -
```

## Advanced Configuration

### Custom Secrets Path

To use a different path than the default:

1. Store secrets at your custom path in Vault
2. Update `.env`:
   ```bash
   VAULT_SECRETS_PATH=custom/path/to/monitoring/secrets
   ```
3. Restart the stack

### Multiple Environments

For dev/staging/production separation:

```bash
# Development
vault kv put secret/ai-monitoring-dev \
  litellm/url="http://dev-litellm:4000" ...

# Production
vault kv put secret/ai-monitoring-prod \
  litellm/url="http://prod-litellm:4000" ...
```

Update `.env` per environment:
```bash
VAULT_SECRETS_PATH=ai-monitoring-prod
```

## Additional Resources

- [Vault KV Secrets Engine](https://www.vaultproject.io/docs/secrets/kv)
- [Vault Policies](https://www.vaultproject.io/docs/concepts/policies)
- [Vault Tokens](https://www.vaultproject.io/docs/concepts/tokens)
- [Vault Best Practices](https://learn.hashicorp.com/tutorials/vault/production-hardening)

## Support

For issues specific to this monitoring stack:
- GitHub Issues: https://github.com/jctux/ai-infrastructure-monitoring/issues

For Vault-specific issues:
- HashiCorp Vault Documentation: https://www.vaultproject.io/docs
- HashiCorp Community Forum: https://discuss.hashicorp.com/c/vault
