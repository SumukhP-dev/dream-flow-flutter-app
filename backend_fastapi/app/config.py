import os
from pathlib import Path
from functools import lru_cache

from dotenv import load_dotenv
from pydantic import BaseModel, ConfigDict, field_validator


PROJECT_ROOT = Path(__file__).resolve().parents[1]
load_dotenv(PROJECT_ROOT / ".env")


def _get_service_role_key() -> str:
    """
    Load Supabase service-role key from environment or Azure Key Vault.
    
    Priority order:
    1. Environment variable SUPABASE_SERVICE_ROLE_KEY (primary method)
    2. Azure Key Vault (if AZURE_KEY_VAULT_URL and AZURE_KEY_VAULT_SECRET_NAME are set)
    
    This key MUST NEVER be committed to the repository. It should be injected via:
    - CI/CD pipeline secrets (GitHub Actions, Azure DevOps, etc.)
    - Environment variables in production
    - Azure Key Vault for Azure deployments
    
    Raises:
        ValueError: If the service-role key cannot be found from any source.
    """
    # First, try environment variable (primary method for CI/CD)
    key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
    if key:
        return key
    
    # Fallback to Azure Key Vault if configured
    vault_url = os.getenv("AZURE_KEY_VAULT_URL")
    secret_name = os.getenv("AZURE_KEY_VAULT_SECRET_NAME", "supabase-service-role-key")
    
    if vault_url:
        try:
            from azure.identity import DefaultAzureCredential
            from azure.keyvault.secrets import SecretClient
            
            credential = DefaultAzureCredential()
            client = SecretClient(vault_url=vault_url, credential=credential)
            secret = client.get_secret(secret_name)
            if secret.value:
                return secret.value
        except ImportError:
            raise ValueError(
                "Azure Key Vault is configured but azure-keyvault-secrets and azure-identity "
                "packages are not installed. Install them with: "
                "pip install azure-keyvault-secrets azure-identity"
            )
        except Exception as e:
            raise ValueError(
                f"Failed to retrieve service-role key from Azure Key Vault: {e}. "
                "Ensure AZURE_KEY_VAULT_URL is set correctly and the application has "
                "proper authentication (Managed Identity, Service Principal, etc.)."
            )
    
    # Fail fast if key is missing
    raise ValueError(
        "SUPABASE_SERVICE_ROLE_KEY is required but not found. "
        "This key must be provided via:\n"
        "  - Environment variable SUPABASE_SERVICE_ROLE_KEY (recommended for CI/CD)\n"
        "  - Azure Key Vault (set AZURE_KEY_VAULT_URL and optionally AZURE_KEY_VAULT_SECRET_NAME)\n\n"
        "The service-role key MUST NEVER be committed to the repository. "
        "Configure it in your CI/CD pipeline secrets or deployment environment."
    )


class Settings(BaseModel):
    model_config = ConfigDict(arbitrary_types_allowed=True)
    app_name: str = "Dream Flow Backend"
    hf_token: str | None = os.getenv("HUGGINGFACE_API_TOKEN")
    story_model: str = os.getenv("STORY_MODEL", "meta-llama/Llama-3.2-1B-Instruct")
    tts_model: str = os.getenv("TTS_MODEL", "suno/bark-small")
    image_model: str = os.getenv("IMAGE_MODEL", "black-forest-labs/FLUX.1-schnell")
    max_new_tokens: int = int(os.getenv("MAX_NEW_TOKENS", "512"))
    asset_dir: Path = Path(os.getenv("ASSET_DIR", PROJECT_ROOT / "storage"))
    
    # Supabase Configuration
    supabase_url: str | None = os.getenv("SUPABASE_URL")
    supabase_anon_key: str | None = os.getenv("SUPABASE_ANON_KEY")
    # Service-role key is required and loaded via _get_service_role_key()
    # This ensures it's never hardcoded and fails fast if missing
    supabase_service_role_key: str
    
    # Admin Configuration
    admin_user_ids: list[str] = os.getenv("ADMIN_USER_IDS", "").split(",") if os.getenv("ADMIN_USER_IDS") else []
    
    # Backend URL (for CORS and external references)
    backend_url: str = os.getenv("BACKEND_URL", "http://localhost:8080")
    
    # Sentry Configuration
    sentry_dsn: str | None = os.getenv("SENTRY_DSN")
    sentry_environment: str = os.getenv("SENTRY_ENVIRONMENT", "development")
    sentry_traces_sample_rate: float = float(os.getenv("SENTRY_TRACES_SAMPLE_RATE", "0.2"))
    
    # Asset Retention Configuration
    asset_retention_days: int = int(os.getenv("ASSET_RETENTION_DAYS", "7"))
    
    # Subscription Configuration
    stripe_secret_key: str | None = os.getenv("STRIPE_SECRET_KEY")
    stripe_webhook_secret: str | None = os.getenv("STRIPE_WEBHOOK_SECRET")
    revenuecat_api_key: str | None = os.getenv("REVENUECAT_API_KEY")
    
    # CDN Configuration
    cdn_url: str | None = os.getenv("CDN_URL")
    cdn_enabled: bool = os.getenv("CDN_ENABLED", "false").lower() == "true"
    
    def __init__(self, **data):
        """Initialize Settings with service-role key loaded from secure source."""
        # Load service-role key before Pydantic validation
        if "supabase_service_role_key" not in data:
            data["supabase_service_role_key"] = _get_service_role_key()
        super().__init__(**data)
    
    @field_validator("supabase_service_role_key")
    @classmethod
    def validate_service_role_key(cls, v: str) -> str:
        """Validate that service-role key is not empty."""
        if not v or not v.strip():
            raise ValueError("SUPABASE_SERVICE_ROLE_KEY cannot be empty")
        return v.strip()

    @property
    def audio_dir(self) -> Path:
        return self.asset_dir / "audio"

    @property
    def frames_dir(self) -> Path:
        return self.asset_dir / "frames"

    @property
    def video_dir(self) -> Path:
        return self.asset_dir / "video"


@lru_cache
def get_settings() -> Settings:
    settings = Settings()
    for directory in (settings.asset_dir, settings.audio_dir, settings.frames_dir, settings.video_dir):
        directory.mkdir(parents=True, exist_ok=True)
    return settings


