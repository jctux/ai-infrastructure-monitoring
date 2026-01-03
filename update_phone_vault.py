#!/usr/bin/env python3
import hvac
import os

# Configuración de Vault
VAULT_ADDR = "http://10.1.0.99:8200"
VAULT_TOKEN = os.getenv("VAULT_TOKEN")
VAULT_SECRETS_PATH = "ai-infrastructure-monitoring"

if not VAULT_TOKEN:
    print("❌ Error: Debes exportar VAULT_TOKEN primero")
    print("   export VAULT_TOKEN='tu-token-aqui'")
    exit(1)

# Conectar a Vault
client = hvac.Client(url=VAULT_ADDR, token=VAULT_TOKEN)

if not client.is_authenticated():
    print("❌ Error: Failed to authenticate with Vault")
    exit(1)

print("✅ Conectado a Vault")

# Leer secretos actuales
try:
    secret = client.secrets.kv.v2.read_secret_version(path=VAULT_SECRETS_PATH)
    data = secret["data"]["data"]
    print(f"✅ Secretos actuales leídos: {len(data)} keys")
except Exception as e:
    print(f"❌ Error leyendo secretos: {e}")
    exit(1)

# Actualizar con tu número
data["twilio/phone_to"] = "+528184665595"

# Escribir de vuelta a Vault
try:
    client.secrets.kv.v2.create_or_update_secret(
        path=VAULT_SECRETS_PATH,
        secret=data
    )
    print("✅ Número de teléfono actualizado en Vault")
    print(f"📱 twilio/phone_to = +528184665595")
except Exception as e:
    print(f"❌ Error escribiendo secretos: {e}")
    exit(1)

print("\n🎉 Configuración completada!")
print("Ahora puedes reconstruir y reiniciar el stack:")
print("  docker-compose build ai-alert-processor")
print("  docker-compose up -d")
