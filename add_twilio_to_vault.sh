#!/bin/bash
# Script para agregar credenciales de Twilio a Vault desde otro path
# Las credenciales de Twilio ya están en Vault, este script las copia al path del proyecto

set -e

# Cargar variables de entorno
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
else
    echo "❌ Error: Archivo .env no encontrado"
    echo "   Crea un archivo .env con VAULT_ADDR y VAULT_TOKEN"
    exit 1
fi

# Verificar que las variables de Vault estén configuradas
if [ -z "$VAULT_ADDR" ] || [ -z "$VAULT_TOKEN" ]; then
    echo "❌ Error: VAULT_ADDR y VAULT_TOKEN deben estar configurados en .env"
    exit 1
fi

echo "🔐 Script para configurar credenciales de Twilio en Vault"
echo "============================================================"
echo "Vault Address: $VAULT_ADDR"
echo "Target Path: ${VAULT_SECRETS_PATH:-ai-infrastructure-monitoring}"
echo ""

# Preguntar la ruta donde están las credenciales de Twilio
read -p "📂 Ingresa el path de Vault donde están las credenciales de Twilio (ej: share/twilio): " TWILIO_SOURCE_PATH

if [ -z "$TWILIO_SOURCE_PATH" ]; then
    echo "❌ Error: Debes especificar el path de origen"
    exit 1
fi

echo ""
echo "📖 Leyendo secretos actuales del proyecto..."
CURRENT_SECRETS=$(vault kv get -format=json secret/${VAULT_SECRETS_PATH:-ai-infrastructure-monitoring} 2>/dev/null | jq -r '.data.data' || echo "{}")

if [ "$CURRENT_SECRETS" = "{}" ]; then
    echo "⚠️  No se encontraron secretos actuales. Se crearán nuevos."
fi

echo "📖 Leyendo credenciales de Twilio desde $TWILIO_SOURCE_PATH..."
TWILIO_SECRETS=$(vault kv get -format=json secret/${TWILIO_SOURCE_PATH} 2>/dev/null | jq -r '.data.data')

if [ -z "$TWILIO_SECRETS" ] || [ "$TWILIO_SECRETS" = "null" ]; then
    echo "❌ Error: No se encontraron credenciales de Twilio en $TWILIO_SOURCE_PATH"
    echo "   Verifica que el path sea correcto y que tengas permisos de lectura"
    exit 1
fi

# Extraer credenciales de Twilio
TWILIO_ACCOUNT_SID=$(echo $TWILIO_SECRETS | jq -r '.account_sid // .twilio_account_sid // ."twilio/account_sid" // empty')
TWILIO_AUTH_TOKEN=$(echo $TWILIO_SECRETS | jq -r '.auth_token // .twilio_auth_token // ."twilio/auth_token" // empty')
TWILIO_PHONE_FROM=$(echo $TWILIO_SECRETS | jq -r '.phone_from // .twilio_phone_from // ."twilio/phone_from" // .from_number // empty')
TWILIO_PHONE_TO=$(echo $TWILIO_SECRETS | jq -r '.phone_to // .twilio_phone_to // ."twilio/phone_to" // .to_number // empty')

# Solicitar número de destino si no está configurado
if [ -z "$TWILIO_PHONE_TO" ] || [ "$TWILIO_PHONE_TO" = "null" ]; then
    read -p "📱 Ingresa tu número de teléfono para recibir alertas (formato: +1234567890): " TWILIO_PHONE_TO
fi

# Verificar que obtuvimos las credenciales necesarias
if [ -z "$TWILIO_ACCOUNT_SID" ] || [ "$TWILIO_ACCOUNT_SID" = "null" ]; then
    echo "❌ Error: No se encontró account_sid en los secretos de Twilio"
    exit 1
fi

if [ -z "$TWILIO_AUTH_TOKEN" ] || [ "$TWILIO_AUTH_TOKEN" = "null" ]; then
    echo "❌ Error: No se encontró auth_token en los secretos de Twilio"
    exit 1
fi

echo ""
echo "✅ Credenciales de Twilio obtenidas:"
echo "   Account SID: ${TWILIO_ACCOUNT_SID:0:10}..."
echo "   Phone From: $TWILIO_PHONE_FROM"
echo "   Phone To: $TWILIO_PHONE_TO"
echo ""

# Extraer secretos actuales del proyecto
LITELLM_URL=$(echo $CURRENT_SECRETS | jq -r '."litellm/url" // empty')
LITELLM_KEY=$(echo $CURRENT_SECRETS | jq -r '."litellm/master_key" // empty')
LITELLM_MODEL=$(echo $CURRENT_SECRETS | jq -r '."litellm/model" // "gpt-4o"')
GRAFANA_USER=$(echo $CURRENT_SECRETS | jq -r '."grafana/admin_user" // "admin"')
GRAFANA_PASS=$(echo $CURRENT_SECRETS | jq -r '."grafana/admin_pass" // empty')

# Validar que tenemos los secretos necesarios del proyecto
if [ -z "$LITELLM_URL" ] || [ "$LITELLM_URL" = "null" ]; then
    echo "⚠️  Advertencia: litellm/url no está configurado"
    read -p "Ingresa LiteLLM URL (ej: http://10.1.0.99:4000): " LITELLM_URL
fi

if [ -z "$LITELLM_KEY" ] || [ "$LITELLM_KEY" = "null" ]; then
    echo "⚠️  Advertencia: litellm/master_key no está configurado"
    read -sp "Ingresa LiteLLM Master Key: " LITELLM_KEY
    echo ""
fi

if [ -z "$GRAFANA_PASS" ] || [ "$GRAFANA_PASS" = "null" ]; then
    echo "⚠️  Advertencia: grafana/admin_pass no está configurado"
    read -sp "Ingresa Grafana Admin Password: " GRAFANA_PASS
    echo ""
fi

echo ""
echo "📝 Escribiendo secretos en Vault..."
vault kv put secret/${VAULT_SECRETS_PATH:-ai-infrastructure-monitoring} \
    litellm/url="$LITELLM_URL" \
    litellm/master_key="$LITELLM_KEY" \
    litellm/model="$LITELLM_MODEL" \
    grafana/admin_user="$GRAFANA_USER" \
    grafana/admin_pass="$GRAFANA_PASS" \
    twilio/account_sid="$TWILIO_ACCOUNT_SID" \
    twilio/auth_token="$TWILIO_AUTH_TOKEN" \
    twilio/phone_from="$TWILIO_PHONE_FROM" \
    twilio/phone_to="$TWILIO_PHONE_TO"

echo ""
echo "✅ Credenciales actualizadas exitosamente en Vault"
echo ""
echo "📋 Verificando secretos escritos..."
vault kv get secret/${VAULT_SECRETS_PATH:-ai-infrastructure-monitoring}

echo ""
echo "✅ Configuración completada. Ahora puedes:"
echo "   1. Reconstruir el contenedor: docker-compose build ai-alert-processor"
echo "   2. Reiniciar el stack: docker-compose up -d"
echo ""
echo "📱 Las notificaciones SMS se enviarán a: $TWILIO_PHONE_TO"
