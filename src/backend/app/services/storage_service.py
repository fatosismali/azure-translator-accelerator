"""
Azure Storage Blob service for batch translation.
"""

import logging
from typing import List, Dict, Any, Optional
from azure.storage.blob import BlobServiceClient, ContainerClient, ContentSettings
from azure.core.exceptions import ResourceNotFoundError
from app.config import get_settings

logger = logging.getLogger(__name__)


class StorageService:
    """Service for Azure Blob Storage operations."""

    def __init__(self):
        """Initialize storage service with settings."""
        self.settings = get_settings()
        self.mock_mode = False
        
        # Check if Azure Storage is configured
        if not self.settings.azure_storage_connection_string and not self.settings.azure_storage_account_name:
            logger.warning(
                "⚠️  Azure Storage not configured - running in MOCK MODE for testing.\n"
                "   To use real storage, set one of:\n"
                "   - AZURE_STORAGE_CONNECTION_STRING (recommended for local/Docker)\n"
                "   - AZURE_STORAGE_ACCOUNT_NAME (for Azure with managed identity)\n"
                "   Mock mode provides sample data but won't save translations."
            )
            self.mock_mode = True
            self.blob_service_client = None
            return
        
        # PRIORITIZE connection string for local development (Docker, local testing)
        # This avoids managed identity issues when running outside Azure
        if self.settings.azure_storage_connection_string:
            logger.info("✓ Storage service initialized with CONNECTION STRING (local/Docker mode)")
            self.blob_service_client = BlobServiceClient.from_connection_string(
                self.settings.azure_storage_connection_string
            )
        else:
            # For Azure deployment with managed identity OR local Docker with Azure CLI
            logger.info(f"✓ Storage service initialized with AZURE AD AUTHENTICATION for account: {self.settings.azure_storage_account_name}")
            logger.info("   Using: Azure CLI credentials (local) or Managed Identity (Azure)")
            storage_url = f"https://{self.settings.azure_storage_account_name}.blob.core.windows.net"
            from azure.identity import DefaultAzureCredential
            credential = DefaultAzureCredential(
                exclude_shared_token_cache_credential=True,
                exclude_visual_studio_code_credential=True,
                exclude_environment_credential=False,  # Enable for Service Principal (AZURE_CLIENT_ID/SECRET/TENANT_ID)
                exclude_managed_identity_credential=False,  # Enable for Azure deployment
                exclude_azure_cli_credential=True  # Disable Azure CLI as it doesn't work in Docker
            )
            self.blob_service_client = BlobServiceClient(
                account_url=storage_url,
                credential=credential
            )

    def list_containers(self) -> List[str]:
        """
        List all blob containers.
        
        Returns:
            List of container names
        """
        # Mock mode for local testing
        if self.mock_mode:
            logger.info("Mock mode: Returning sample containers")
            return ["source-documents", "translations", "test-files"]
        
        try:
            containers = self.blob_service_client.list_containers()
            return [container.name for container in containers]
        except Exception as e:
            logger.error(f"Failed to list containers: {str(e)}")
            raise

    def list_blobs(self, container_name: str, prefix: Optional[str] = None) -> List[Dict[str, Any]]:
        """
        List blobs in a container.
        
        Args:
            container_name: Container name
            prefix: Optional prefix to filter blobs
            
        Returns:
            List of blob info dictionaries
        """
        # Mock mode for local testing
        if self.mock_mode:
            logger.info(f"Mock mode: Returning sample files for {container_name}")
            if container_name == "source-documents":
                return [
                    {'name': 'document1.txt', 'size': 1024, 'last_modified': '2024-01-01T00:00:00', 'content_type': 'text/plain'},
                    {'name': 'document2.txt', 'size': 2048, 'last_modified': '2024-01-02T00:00:00', 'content_type': 'text/plain'},
                    {'name': 'sample.txt', 'size': 512, 'last_modified': '2024-01-03T00:00:00', 'content_type': 'text/plain'},
                ]
            elif container_name == "translations" and prefix:
                if prefix.startswith("nmt"):
                    return [
                        {'name': 'nmt/document1.txt', 'size': 1100, 'last_modified': '2024-01-04T00:00:00', 'content_type': 'text/plain'},
                        {'name': 'nmt/document2.txt', 'size': 2200, 'last_modified': '2024-01-05T00:00:00', 'content_type': 'text/plain'},
                    ]
                elif prefix.startswith("llm"):
                    return [
                        {'name': 'llm/document1.txt', 'size': 1150, 'last_modified': '2024-01-04T00:00:00', 'content_type': 'text/plain'},
                        {'name': 'llm/document2.txt', 'size': 2250, 'last_modified': '2024-01-05T00:00:00', 'content_type': 'text/plain'},
                    ]
            return []
        
        try:
            container_client = self.blob_service_client.get_container_client(container_name)
            
            blobs = []
            for blob in container_client.list_blobs(name_starts_with=prefix):
                # Only include .txt files
                if blob.name.endswith('.txt'):
                    blobs.append({
                        'name': blob.name,
                        'size': blob.size,
                        'last_modified': blob.last_modified.isoformat() if blob.last_modified else None,
                        'content_type': blob.content_settings.content_type if blob.content_settings else None,
                    })
            
            logger.info(f"Listed {len(blobs)} text files from container {container_name}")
            return blobs
        
        except ResourceNotFoundError:
            logger.error(f"Container {container_name} not found")
            raise
        except Exception as e:
            logger.error(f"Failed to list blobs: {str(e)}")
            raise

    def read_blob(self, container_name: str, blob_name: str) -> str:
        """
        Read blob content as text.
        
        Args:
            container_name: Container name
            blob_name: Blob name
            
        Returns:
            Blob content as string
        """
        # Mock mode for local testing
        if self.mock_mode:
            logger.info(f"Mock mode: Returning sample content for {blob_name}")
            if "nmt" in blob_name:
                return f"This is a sample NMT translation of {blob_name}. Neural Machine Translation provides fast and accurate results."
            elif "llm" in blob_name:
                return f"This is a sample LLM translation of {blob_name}. Large Language Model translation offers contextual and natural-sounding results with better understanding of nuance and tone."
            else:
                return f"This is sample content from {blob_name}. Lorem ipsum dolor sit amet, consectetur adipiscing elit."
        
        try:
            blob_client = self.blob_service_client.get_blob_client(
                container=container_name,
                blob=blob_name
            )
            
            downloader = blob_client.download_blob()
            content = downloader.readall().decode('utf-8')
            
            logger.info(f"Read blob {blob_name} from {container_name} ({len(content)} chars)")
            return content
        
        except Exception as e:
            logger.error(f"Failed to read blob {blob_name}: {str(e)}")
            raise

    def write_blob(
        self,
        container_name: str,
        blob_name: str,
        content: str,
        overwrite: bool = True
    ) -> None:
        """
        Write text content to blob.
        
        Args:
            container_name: Container name
            blob_name: Blob name
            content: Text content to write
            overwrite: Whether to overwrite existing blob
        """
        # Mock mode for local testing
        if self.mock_mode:
            logger.info(f"Mock mode: Simulating write of {blob_name} to {container_name} ({len(content)} chars)")
            return
        
        try:
            blob_client = self.blob_service_client.get_blob_client(
                container=container_name,
                blob=blob_name
            )
            
            blob_client.upload_blob(
                content.encode('utf-8'),
                overwrite=overwrite,
                content_settings=ContentSettings(content_type='text/plain; charset=utf-8')
            )
            
            logger.info(f"Wrote blob {blob_name} to {container_name} ({len(content)} chars)")
        
        except Exception as e:
            logger.error(f"Failed to write blob {blob_name}: {str(e)}")
            raise

    def ensure_container_exists(self, container_name: str) -> None:
        """
        Ensure a container exists, create if it doesn't.
        
        Args:
            container_name: Container name
        """
        # Mock mode for local testing
        if self.mock_mode:
            logger.info(f"Mock mode: Simulating container check for {container_name}")
            return
        
        try:
            container_client = self.blob_service_client.get_container_client(container_name)
            
            if not container_client.exists():
                container_client.create_container()
                logger.info(f"Created container {container_name}")
            else:
                logger.info(f"Container {container_name} already exists")
        
        except Exception as e:
            logger.error(f"Failed to ensure container exists: {str(e)}")
            raise

