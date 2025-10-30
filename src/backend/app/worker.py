#!/usr/bin/env python3
"""
Background worker for processing batch translation queue messages.

This worker continuously polls Azure Queue Storage for batch translation jobs
and processes them asynchronously.

Usage:
    python -m app.worker
    
Or in production:
    uvicorn app.worker:app --workers 2
"""

import asyncio
import logging
import signal
import sys
from typing import Optional

from app.config import get_settings
from app.services.storage_service import StorageService
from app.services.queue_service import QueueService
from app.services.translator_service import TranslatorService
from app.services.batch_service import BatchTranslationService

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class BatchWorker:
    """Background worker for processing batch translation jobs."""
    
    def __init__(self):
        """Initialize worker with required services."""
        self.settings = get_settings()
        self.running = False
        self.storage_service = StorageService()
        self.queue_service = QueueService(queue_name="translation-jobs")
        self.translator_service = TranslatorService(self.settings)
        self.batch_service = BatchTranslationService(
            self.storage_service,
            self.queue_service,
            self.translator_service
        )
        logger.info("Batch worker initialized")
    
    async def process_messages(self):
        """Continuously poll queue and process messages."""
        logger.info("Worker started - polling for messages...")
        
        while self.running:
            try:
                # Receive up to 10 messages at once
                messages = self.queue_service.receive_messages(
                    max_messages=10,
                    visibility_timeout=300  # 5 minutes to process each message
                )
                
                processed_count = 0
                for message in messages:
                    try:
                        logger.info(f"Processing message: {message.id}")
                        
                        # Parse message content
                        import json
                        message_content = json.loads(message.content)
                        
                        # Process the translation job
                        await self.batch_service.process_queue_message(message_content)
                        
                        # Delete message from queue after successful processing
                        self.queue_service.delete_message(message.id, message.pop_receipt)
                        processed_count += 1
                        
                        logger.info(f"Message {message.id} processed successfully")
                        
                    except Exception as e:
                        logger.error(f"Error processing message {message.id}: {str(e)}")
                        # Message will become visible again after visibility_timeout
                        # Azure Queue will retry up to dequeue_count times
                
                if processed_count > 0:
                    logger.info(f"Processed {processed_count} messages in this batch")
                
                # Wait a bit before checking queue again (avoid tight loop)
                await asyncio.sleep(2)
                
            except Exception as e:
                logger.error(f"Error in worker loop: {str(e)}")
                await asyncio.sleep(5)  # Wait longer on error
    
    async def start(self):
        """Start the worker."""
        self.running = True
        logger.info("=" * 60)
        logger.info("Batch Translation Worker Starting")
        logger.info("=" * 60)
        logger.info(f"Queue: translation-jobs")
        logger.info(f"Environment: {self.settings.environment}")
        logger.info(f"Region: {self.settings.azure_translator_region}")
        logger.info("=" * 60)
        
        await self.process_messages()
    
    def stop(self):
        """Stop the worker gracefully."""
        logger.info("Stopping worker...")
        self.running = False


# Global worker instance
worker: Optional[BatchWorker] = None


async def main():
    """Main entry point for the worker."""
    global worker
    worker = BatchWorker()
    
    # Setup signal handlers for graceful shutdown
    def signal_handler(signum, frame):
        logger.info(f"Received signal {signum}")
        if worker:
            worker.stop()
        sys.exit(0)
    
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    try:
        await worker.start()
    except KeyboardInterrupt:
        logger.info("Worker interrupted by user")
        worker.stop()
    except Exception as e:
        logger.error(f"Worker failed: {str(e)}")
        raise


if __name__ == "__main__":
    asyncio.run(main())
