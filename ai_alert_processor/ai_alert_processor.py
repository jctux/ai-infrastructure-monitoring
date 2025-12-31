import logging
import os
import json
import httpx
from fastapi import FastAPI, Request, BackgroundTasks
from pydantic import BaseModel
from typing import List, Optional, Dict, Any
import hvac

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

        # Read secrets from Vault
        secret = client.secrets.kv.v2.read_secret_version(path=VAULT_SECRETS_PATH)
        data = secret["data"]["data"]

        return {
            "litellm_url": data.get("litellm/url"),
            "litellm_key": data.get("litellm/master_key"),
            "model_name": data.get("litellm/model", "gpt-4o"),
        }
    except Exception as e:
        logger.error(f"Error fetching secrets from Vault: {str(e)}")
        # Fallback to environment variables
        return {
            "litellm_url": os.getenv("LITELLM_URL", "http://litellm-proxy:4000"),
            "litellm_key": os.getenv("LITELLM_MASTER_KEY"),
            "model_name": os.getenv("AI_MODEL", "gpt-4o"),
        }


# Load configuration from Vault
secrets = get_vault_secrets()
LITELLM_URL = secrets["litellm_url"]
LITELLM_KEY = secrets["litellm_key"]
MODEL_NAME = secrets["model_name"]

logger.info(f"Configured with LiteLLM URL: {LITELLM_URL}, Model: {MODEL_NAME}")


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

        system_prompt = """You are a Senior Site Reliability Engineer (SRE). 
Your job is to analyze incoming infrastructure alerts, determine the likely root cause, and suggest immediate remediation steps.
Keep your response concise, actionable, and formatted in Markdown.
"""

        user_prompt = f"""
Analyze the following alerts occurring in our infrastructure:

{alert_summary}

Context:
- Environment: Enterprise Production
- Services: Frigate (NVR), LiteLLM (AI Gateway), TrueNAS (Storage)

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
                # TODO: In the future, send this to Slack/Email
            else:
                logger.error(
                    f"🔴 Failed to call LiteLLM: {response.status_code} - {response.text}"
                )

    except Exception as e:
        logger.error(f"Error during AI analysis: {str(e)}")


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
