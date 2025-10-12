"""
Background worker for processing translation queue messages.
"""

import asyncio
import json
import logging
import signal
import sys
from datetime import datetime
from app.services.storage_service import StorageService
from app.services.queue_service import QueueService
from app.services.translator_service import TranslatorService
from app.services.batch_service import BatchTranslationService
from app.config import get_settings

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Global flag for graceful shutdown
running = True


def signal_handler(sig, frame):
    """Handle shutdown signals."""
    global running
    logger.info("Received shutdown signal, finishing current message...")
    running = False


async def process_messages():
    """Main worker loop to process queue messages."""
    settings = get_settings()
    
    # Initialize services
    storage = StorageService()
    queue = QueueService(queue_name="translation-jobs")
    translator = TranslatorService(settings)
    batch_service = BatchTranslationService(storage, queue, translator)
    
    logger.info("Worker started, polling for messages...")
    
    while running:
        try:
            # Receive messages from queue
            messages = queue.receive_messages(max_messages=1, visibility_timeout=600)  # 10 min timeout
            
            for message in messages:
                try:
                    # Parse message content
                    content = json.loads(message.content)
                    logger.info(f"Processing message {message.id}: {content.get('source_blob')}")
                    
                    # Process the translation job
                    await batch_service.process_queue_message(content)
                    
                    # Delete message after successful processing
                    queue.delete_message(message.id, message.pop_receipt)
                    logger.info(f"Successfully processed and deleted message {message.id}")
                
                except json.JSONDecodeError as e:
                    logger.error(f"Failed to parse message {message.id}: {str(e)}")
                    queue.delete_message(message.id, message.pop_receipt)
                
                except Exception as e:
                    logger.error(f"Failed to process message {message.id}: {str(e)}", exc_info=True)
                    # Don't delete message - it will become visible again for retry
            
            # Sleep briefly before next poll (only if no messages were processed)
            if not any(messages):
                await asyncio.sleep(5)  # Poll every 5 seconds
        
        except KeyboardInterrupt:
            logger.info("Received keyboard interrupt")
            break
        
        except Exception as e:
            logger.error(f"Worker error: {str(e)}", exc_info=True)
            await asyncio.sleep(10)  # Wait before retrying after error
    
    logger.info("Worker stopped")


def main():
    """Main entry point."""
    # Register signal handlers for graceful shutdown
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    logger.info("Starting translation worker...")
    
    # Run the async worker
    asyncio.run(process_messages())


if __name__ == "__main__":
    main()

