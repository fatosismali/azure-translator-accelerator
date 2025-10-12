"""
Azure Queue Storage service for batch translation jobs.
"""

import json
import logging
from typing import Dict, Any, Optional
from azure.storage.queue import QueueServiceClient, QueueClient
from azure.core.exceptions import ResourceNotFoundError
from app.config import get_settings

logger = logging.getLogger(__name__)


class QueueService:
    """Service for Azure Queue Storage operations."""

    def __init__(self, queue_name: str = "translation-jobs"):
        """
        Initialize queue service.
        
        Args:
            queue_name: Name of the queue to use
        """
        self.settings = get_settings()
        self.queue_name = queue_name
        
        # Initialize queue service client
        if self.settings.azure_storage_connection_string:
            self.queue_service_client = QueueServiceClient.from_connection_string(
                self.settings.azure_storage_connection_string
            )
        else:
            # For cloud deployment with managed identity
            queue_url = f"https://{self.settings.azure_storage_account_name}.queue.core.windows.net"
            from azure.identity import DefaultAzureCredential
            credential = DefaultAzureCredential()
            self.queue_service_client = QueueServiceClient(
                account_url=queue_url,
                credential=credential
            )
        
        self.queue_client = self.queue_service_client.get_queue_client(queue_name)
        
        # Ensure queue exists
        self._ensure_queue_exists()
        
        logger.info(f"Queue service initialized for queue: {queue_name}")

    def _ensure_queue_exists(self) -> None:
        """Ensure the queue exists, create if it doesn't."""
        try:
            if not self.queue_client.exists():
                self.queue_client.create_queue()
                logger.info(f"Created queue: {self.queue_name}")
        except Exception as e:
            logger.error(f"Failed to ensure queue exists: {str(e)}")
            # Don't raise - queue might already exist

    def send_message(self, message: Dict[str, Any]) -> str:
        """
        Send a message to the queue.
        
        Args:
            message: Message dictionary to send
            
        Returns:
            Message ID
        """
        try:
            message_str = json.dumps(message)
            response = self.queue_client.send_message(message_str)
            
            logger.info(f"Sent message to queue: {response.id}")
            return response.id
        
        except Exception as e:
            logger.error(f"Failed to send message: {str(e)}")
            raise

    def receive_messages(self, max_messages: int = 1, visibility_timeout: int = 300):
        """
        Receive messages from the queue.
        
        Args:
            max_messages: Maximum number of messages to receive
            visibility_timeout: Visibility timeout in seconds (5 minutes default)
            
        Returns:
            List of messages
        """
        try:
            messages = self.queue_client.receive_messages(
                messages_per_page=max_messages,
                visibility_timeout=visibility_timeout
            )
            return messages
        
        except Exception as e:
            logger.error(f"Failed to receive messages: {str(e)}")
            raise

    def delete_message(self, message_id: str, pop_receipt: str) -> None:
        """
        Delete a message from the queue.
        
        Args:
            message_id: Message ID
            pop_receipt: Pop receipt from received message
        """
        try:
            self.queue_client.delete_message(message_id, pop_receipt)
            logger.info(f"Deleted message: {message_id}")
        
        except Exception as e:
            logger.error(f"Failed to delete message {message_id}: {str(e)}")
            raise

    def get_queue_length(self) -> int:
        """
        Get approximate number of messages in queue.
        
        Returns:
            Approximate message count
        """
        try:
            properties = self.queue_client.get_queue_properties()
            count = properties.approximate_message_count
            logger.info(f"Queue {self.queue_name} has ~{count} messages")
            return count
        
        except Exception as e:
            logger.error(f"Failed to get queue length: {str(e)}")
            return 0

    def clear_queue(self) -> None:
        """Clear all messages from the queue."""
        try:
            self.queue_client.clear_messages()
            logger.info(f"Cleared queue: {self.queue_name}")
        
        except Exception as e:
            logger.error(f"Failed to clear queue: {str(e)}")
            raise

