import logging
import os
import json
import httpx
from fastapi import FastAPI, Request, BackgroundTasks
from pydantic import BaseModel
from typing import List, Optional, Dict, Any
import hvac
from twilio.rest import Client as TwilioClient

# Configure logging
logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger("AI-Alert-Processor")

app = FastAPI()

# Vault Configuration
VAULT_ADDR = os.getenv("VAULT_ADDR", "http://vault:8200")
VAULT_TOKEN = os.getenv("VAULT_TOKEN")
VAULT_SECRETS_PATH = os.getenv("VAULT_SECRETS_PATH", "ai-infrastructure-monitoring")


def get_vault_secrets():
    """Retrieve secrets from Vault"""
    try:
        client = hvac.Client(url=VAULT_ADDR, token=VAULT_TOKEN)
        if not client.is_authenticated():
            logger.error("Failed to authenticate with Vault")
            raise Exception("Vault authentication failed")

        # Read LiteLLM/Grafana secrets from main path
        secret = client.secrets.kv.v2.read_secret_version(path=VAULT_SECRETS_PATH)
        data = secret["data"]["data"]

        # Read Twilio secrets from icegg-app/twilio
        twilio_secret = client.secrets.kv.v2.read_secret_version(
            path="icegg-app/twilio"
        )
        twilio_data = twilio_secret["data"]["data"]

        return {
            "litellm_url": data.get("litellm/url"),
            "litellm_key": data.get("litellm/master_key"),
            "model_name": data.get("litellm/model", "gpt-4o"),
            "twilio_account_sid": twilio_data.get("account_sid"),
            "twilio_auth_token": twilio_data.get("auth_token"),
            "twilio_phone_from": twilio_data.get("phone_number"),
            "twilio_phone_to": twilio_data.get("phone_to"),
        }
    except Exception as e:
        logger.error(f"Error fetching secrets from Vault: {str(e)}")
        # Fallback to environment variables
        return {
            "litellm_url": os.getenv("LITELLM_URL", "http://litellm-proxy:4000"),
            "litellm_key": os.getenv("LITELLM_MASTER_KEY"),
            "model_name": os.getenv("AI_MODEL", "gpt-4o"),
            "twilio_account_sid": os.getenv("TWILIO_ACCOUNT_SID"),
            "twilio_auth_token": os.getenv("TWILIO_AUTH_TOKEN"),
            "twilio_phone_from": os.getenv("TWILIO_PHONE_FROM"),
            "twilio_phone_to": os.getenv("TWILIO_PHONE_TO"),
        }


# Load configuration from Vault
secrets = get_vault_secrets()
LITELLM_URL = secrets["litellm_url"]
LITELLM_KEY = secrets["litellm_key"]
MODEL_NAME = secrets["model_name"]
TWILIO_ACCOUNT_SID = secrets["twilio_account_sid"]
TWILIO_AUTH_TOKEN = secrets["twilio_auth_token"]
TWILIO_PHONE_FROM = secrets["twilio_phone_from"]
TWILIO_PHONE_TO = secrets["twilio_phone_to"]

logger.info(f"Configured with LiteLLM URL: {LITELLM_URL}, Model: {MODEL_NAME}")

# Initialize Twilio client if credentials are available
twilio_client = None
if TWILIO_ACCOUNT_SID and TWILIO_AUTH_TOKEN:
    try:
        twilio_client = TwilioClient(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN)
        logger.info(
            f"✅ Twilio client initialized. SMS notifications enabled to {TWILIO_PHONE_TO}"
        )
    except Exception as e:
        logger.error(f"❌ Failed to initialize Twilio client: {str(e)}")
else:
    logger.warning("⚠️  Twilio credentials not found. SMS notifications disabled.")


class Alert(BaseModel):
    status: str
    labels: Dict[str, str]
    annotations: Dict[str, str]
    startsAt: str
    endsAt: Optional[str] = None
    generatorURL: str


class WebhookPayload(BaseModel):
    version: str
    groupKey: str
    truncatedAlerts: int
    status: str
    receiver: str
    groupLabels: Dict[str, str]
    commonLabels: Dict[str, str]
    commonAnnotations: Dict[str, str]
    externalURL: str
    alerts: List[Alert]


def send_sms(message: str):
    """Send SMS notification via Twilio"""
    if not twilio_client:
        logger.warning("Twilio client not initialized. Skipping SMS.")
        return False

    try:
        # Truncate message if too long (SMS limit is 1600 chars)
        if len(message) > 1500:
            message = message[:1497] + "..."

        sms = twilio_client.messages.create(
            body=message, from_=TWILIO_PHONE_FROM, to=TWILIO_PHONE_TO
        )
        logger.info(f"📱 SMS sent successfully. SID: {sms.sid}")
        return True
    except Exception as e:
        logger.error(f"❌ Failed to send SMS: {str(e)}")
        return False


async def analyze_alert_with_ai(payload: Dict[str, Any]):
    """
    Sends the alert context to LiteLLM to get an analysis and remediation suggestion.
    """
    try:
        alerts = payload.get("alerts", [])
        if not alerts:
            return

        # Construct a prompt for the AI
        alert_summary = "\n".join(
            [
                f"- [{a['status'].upper()}] {a['labels'].get('alertname', 'Unknown')}: {a['annotations'].get('summary', 'No summary')}"
                for a in alerts
            ]
        )

        # 📱 NOTIFICACIÓN 1: ENTRADA AL LLM
        alert_names = ", ".join(
            [a["labels"].get("alertname", "Unknown") for a in alerts]
        )
        entry_message = f"🚨 ALERTA RECIBIDA\n\nAlertas: {alert_names}\n\n🤖 Enviando a AI para análisis..."
        logger.info(f"📱 Sending entry notification: {alert_names}")
        send_sms(entry_message)

        system_prompt = """You are a Senior Site Reliability Engineer (SRE). 
Your job is to analyze incoming infrastructure alerts, determine the likely root cause, and suggest immediate remediation steps.
Keep your response concise, actionable, and formatted in Markdown.
"""

        user_prompt = f"""
Analyze the following alerts occurring in our infrastructure:

{alert_summary}

Provide:
1. Severity Assessment (Low/Medium/High/Critical)
2. Probable Root Cause
3. Recommended Remediation Steps
"""

        # Call LiteLLM
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{LITELLM_URL}/chat/completions",
                headers={"Authorization": f"Bearer {LITELLM_KEY}"},
                json={
                    "model": MODEL_NAME,
                    "messages": [
                        {"role": "system", "content": system_prompt},
                        {"role": "user", "content": user_prompt},
                    ],
                },
                timeout=30.0,
            )

            if response.status_code == 200:
                ai_response = response.json()
                content = ai_response["choices"][0]["message"]["content"]
                logger.info(f"🟢 AI ANALYSIS RESULT:\n{content}")

                # 📱 NOTIFICACIÓN 2: SALIDA DEL LLM
                output_message = (
                    f"✅ ANÁLISIS AI COMPLETADO\n\nAlerta: {alert_names}\n\n{content}"
                )
                logger.info(f"📱 Sending AI analysis result via SMS")
                send_sms(output_message)

            else:
                error_msg = f"🔴 Failed to call LiteLLM: {response.status_code} - {response.text}"
                logger.error(error_msg)

                # Notificar error también
                error_sms = f"❌ ERROR EN ANÁLISIS AI\n\nAlerta: {alert_names}\n\nError: {response.status_code}"
                send_sms(error_sms)

    except Exception as e:
        logger.error(f"Error during AI analysis: {str(e)}")
        # Notificar excepción
        error_sms = f"❌ EXCEPCIÓN EN PROCESAMIENTO\n\nError: {str(e)[:200]}"
        send_sms(error_sms)


@app.post("/webhook")
async def receive_alert(request: Request, background_tasks: BackgroundTasks):
    try:
        payload = await request.json()
        logger.info(f"Received webhook payload: {json.dumps(payload, indent=2)}")

        # Trigger AI analysis in the background to not block the Alertmanager
        background_tasks.add_task(analyze_alert_with_ai, payload)

        return {"status": "received", "processing": True}
    except Exception as e:
        logger.error(f"Error processing webhook: {str(e)}")
        return {"status": "error", "message": str(e)}


@app.get("/health")
def health_check():
    return {"status": "ok"}


if __name__ == "__main__":
    import uvicorn

    port = int(os.getenv("PORT", "5050"))
    uvicorn.run(app, host="0.0.0.0", port=port)
