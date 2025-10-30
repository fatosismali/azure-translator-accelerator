"""
Configuration management using Pydantic Settings.
Supports environment variables, .env files, and Azure Key Vault.
"""

import os
from typing import Optional
from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings with validation."""
    
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore"
    )
    
    # Application
    app_name: str = Field(default="translator-accelerator", description="Application name")
    app_version: str = Field(default="1.0.0", description="Application version")
    environment: str = Field(default="development", description="Environment (development, production)")
    debug: bool = Field(default=False, description="Debug mode")
    log_level: str = Field(default="INFO", description="Logging level")
    
    # API
    api_v1_prefix: str = Field(default="/api/v1", description="API v1 prefix")
    backend_cors_origins: str = Field(
        default='["http://localhost:3000","http://localhost:5173"]',
        description="CORS origins (JSON array string)"
    )
    
    # Azure Translator
    azure_translator_key: str = Field(..., description="Azure Translator API key")
    azure_translator_region: str = Field(default="westeurope", description="Azure Translator region")
    azure_translator_endpoint: str = Field(
        default="https://api.cognitive.microsofttranslator.com",
        description="Azure Translator endpoint"
    )
    azure_translator_api_version: str = Field(default="3.0", description="Translator API version")
    azure_translator_api_version_preview: str = Field(default="2025-05-01-preview", description="Translator API preview version")
    
    # Azure AI Foundry (for LLM translation)
    azure_ai_foundry_endpoint: Optional[str] = Field(default=None, description="Azure AI Foundry endpoint for LLM")
    azure_ai_foundry_key: Optional[str] = Field(default=None, description="Azure AI Foundry API key")
    gpt4o_mini_deployment_name: str = Field(default="gpt-4o-mini", description="GPT-4o-mini deployment name")
    
    # Azure Key Vault
    azure_key_vault_url: Optional[str] = Field(default=None, description="Azure Key Vault URL")
    
    # Azure Storage
    azure_storage_connection_string: Optional[str] = Field(
        default=None,
        description="Azure Storage connection string"
    )
    azure_storage_account_name: Optional[str] = Field(default=None, description="Storage account name")
    azure_storage_container_name: str = Field(default="translations", description="Storage container")
    
    # Application Insights
    applicationinsights_connection_string: Optional[str] = Field(
        default=None,
        description="Application Insights connection string"
    )
    appinsights_instrumentationkey: Optional[str] = Field(
        default=None,
        description="Application Insights instrumentation key"
    )
    
    # Feature Flags
    enable_telemetry: bool = Field(default=False, description="Enable telemetry")
    enable_caching: bool = Field(default=False, description="Enable caching")
    enable_transliteration: bool = Field(default=True, description="Enable transliteration")
    enable_dictionary: bool = Field(default=True, description="Enable dictionary lookup")
    enable_batch_queue: bool = Field(default=True, description="Enable queue-based batch processing")
    
    # Rate Limiting
    rate_limit_enabled: bool = Field(default=True, description="Enable rate limiting")
    rate_limit_per_minute: int = Field(default=60, description="Requests per minute")
    
    # Translation Limits
    max_translation_length: int = Field(default=50000, description="Max characters per translation")
    max_batch_size: int = Field(default=100, description="Max texts per batch request")
    default_language: str = Field(default="en", description="Default language code")
    
    # Cost Controls
    translation_quota_daily: int = Field(default=1000000, description="Daily translation quota")
    alert_on_quota_percent: int = Field(default=80, description="Alert threshold percentage")
    
    @property
    def cors_origins(self) -> list[str]:
        """Parse CORS origins from JSON string."""
        import json
        try:
            return json.loads(self.backend_cors_origins)
        except json.JSONDecodeError:
            return ["http://localhost:3000", "http://localhost:5173"]
    
    @property
    def is_production(self) -> bool:
        """Check if running in production."""
        return self.environment.lower() == "production"
    
    @property
    def translator_base_url(self) -> str:
        """Get Translator API base URL."""
        return self.azure_translator_endpoint.rstrip("/")


# Global settings instance
settings = Settings()


def get_settings() -> Settings:
    """Dependency injection for settings."""
    return settings

