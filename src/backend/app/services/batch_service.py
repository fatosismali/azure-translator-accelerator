"""
Batch translation service for processing files from blob storage.
"""

import logging
import uuid
from datetime import datetime
from typing import Dict, Any, List, Optional
from app.services.storage_service import StorageService
from app.services.queue_service import QueueService
from app.services.translator_service import TranslatorService

logger = logging.getLogger(__name__)


class BatchTranslationService:
    """Service for batch translation operations."""

    def __init__(
        self,
        storage_service: StorageService,
        queue_service: QueueService,
        translator_service: TranslatorService
    ):
        """
        Initialize batch translation service.
        
        Args:
            storage_service: Storage service instance
            queue_service: Queue service instance
            translator_service: Translator service instance
        """
        self.storage = storage_service
        self.queue = queue_service
        self.translator = translator_service
        logger.info("Batch translation service initialized")

    async def start_batch_job(
        self,
        source_container: str,
        target_container: str,
        target_language: str,
        source_language: Optional[str] = None,
        prefix: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Start a batch translation job.
        
        Args:
            source_container: Source blob container name
            target_container: Target blob container name
            target_language: Target language code
            source_language: Optional source language code
            prefix: Optional prefix to filter source files
            
        Returns:
            Job information dictionary
        """
        job_id = str(uuid.uuid4())
        
        # Validate source and target containers are different
        if source_container == target_container:
            raise ValueError("Source and target containers must be different to avoid overwriting source files")
        
        try:
            # Ensure target container exists
            self.storage.ensure_container_exists(target_container)
            
            # List all text files from source container
            blobs = self.storage.list_blobs(source_container, prefix=prefix)
            
            if not blobs:
                logger.warning(f"No text files found in {source_container}")
                return {
                    'job_id': job_id,
                    'status': 'completed',
                    'total_files': 0,
                    'message': 'No text files found in source container'
                }
            
            # Process files immediately (without queue for local testing)
            # For production, use queue-based processing with background workers
            
            total_files = len(blobs)
            processed_files = 0
            failed_files = 0
            
            logger.info(f"Batch job {job_id} started: Processing {total_files} files")
            
            for blob in blobs:
                try:
                    blob_name = blob['name']
                    logger.info(f"Processing file {processed_files + 1}/{total_files}: {blob_name}")
                    
                    # Read source file
                    content = self.storage.read_blob(source_container, blob_name)
                    
                    if not content.strip():
                        logger.warning(f"Empty file: {blob_name}")
                        failed_files += 1
                        continue
                    
                    # Extract filename for target paths
                    filename = blob_name.split('/')[-1]
                    
                    # Translate with NMT
                    try:
                        nmt_result = await self.translator.translate(
                            text=content,
                            to=[target_language],
                            from_lang=source_language
                        )
                        nmt_translation = nmt_result[0]['translations'][0]['text']
                        
                        # Save NMT translation
                        nmt_path = f"nmt/{filename}"
                        self.storage.write_blob(target_container, nmt_path, nmt_translation)
                        logger.info(f"NMT translation saved: {nmt_path}")
                    except Exception as e:
                        logger.error(f"NMT translation failed for {blob_name}: {str(e)}")
                        failed_files += 1
                        continue
                    
                    # Translate with LLM
                    try:
                        llm_result = await self.translator.translate_with_llm(
                            text=content,
                            to=[target_language],
                            from_lang=source_language,
                            model="gpt-4o-mini"
                        )
                        llm_translation = llm_result[0]['translations'][0]['text']
                        
                        # Save LLM translation
                        llm_path = f"llm/{filename}"
                        self.storage.write_blob(target_container, llm_path, llm_translation)
                        logger.info(f"LLM translation saved: {llm_path}")
                    except Exception as e:
                        logger.error(f"LLM translation failed for {blob_name}: {str(e)}")
                        # Don't increment failed_files if NMT succeeded
                    
                    processed_files += 1
                    
                except Exception as e:
                    logger.error(f"Failed to process {blob['name']}: {str(e)}")
                    failed_files += 1
            
            logger.info(f"Batch job {job_id} completed: {processed_files}/{total_files} files processed, {failed_files} failed")
            
            return {
                'job_id': job_id,
                'status': 'completed',
                'total_files': total_files,
                'processed_files': processed_files,
                'failed_files': failed_files,
                'source_container': source_container,
                'target_container': target_container,
                'target_language': target_language,
                'source_language': source_language,
                'created_at': datetime.utcnow().isoformat(),
                'completed_at': datetime.utcnow().isoformat()
            }
        
        except Exception as e:
            logger.error(f"Failed to start batch job: {str(e)}")
            raise

    async def process_queue_message(self, message_content: Dict[str, Any]) -> None:
        """
        Process a single translation job from the queue.
        
        Args:
            message_content: Message content dictionary
        """
        try:
            job_id = message_content['job_id']
            source_container = message_content['source_container']
            target_container = message_content['target_container']
            source_blob = message_content['source_blob']
            target_language = message_content['target_language']
            source_language = message_content.get('source_language')
            
            logger.info(f"Processing job {job_id}: {source_blob}")
            
            # Read source file
            content = self.storage.read_blob(source_container, source_blob)
            
            if not content.strip():
                logger.warning(f"Empty file: {source_blob}")
                return
            
            # Translate with NMT
            nmt_result = await self.translator.translate(
                text=content,
                to=[target_language],
                from_lang=source_language
            )
            
            nmt_translation = nmt_result[0]['translations'][0]['text']
            
            # Translate with LLM
            llm_result = await self.translator.translate_with_llm(
                text=content,
                to=[target_language],
                from_lang=source_language,
                model="gpt-4o-mini"
            )
            
            llm_translation = llm_result[0]['translations'][0]['text']
            
            # Store translations in target container
            # Structure: target_container/nmt/filename and target_container/llm/filename
            base_name = source_blob.split('/')[-1]  # Get filename without path
            
            nmt_blob_name = f"nmt/{base_name}"
            llm_blob_name = f"llm/{base_name}"
            
            self.storage.write_blob(target_container, nmt_blob_name, nmt_translation)
            self.storage.write_blob(target_container, llm_blob_name, llm_translation)
            
            logger.info(f"Successfully processed {source_blob}")
        
        except Exception as e:
            logger.error(f"Failed to process message: {str(e)}")
            raise

    def get_job_status(self, job_id: str) -> Dict[str, Any]:
        """
        Get status of a batch job.
        
        Args:
            job_id: Job ID
            
        Returns:
            Job status information
        """
        # Get queue length (approximate pending jobs)
        queue_length = self.queue.get_queue_length()
        
        # In a production system, you'd track job status in a database
        # For now, we'll return queue status
        return {
            'job_id': job_id,
            'queue_length': queue_length,
            'status': 'processing' if queue_length > 0 else 'completed'
        }

    def list_translated_files(self, container_name: str) -> Dict[str, List[Dict[str, Any]]]:
        """
        List all translated files in a container.
        
        Args:
            container_name: Container name
            
        Returns:
            Dictionary with nmt and llm file lists
        """
        try:
            nmt_files = self.storage.list_blobs(container_name, prefix="nmt/")
            llm_files = self.storage.list_blobs(container_name, prefix="llm/")
            
            # Match files by name
            matched_files = []
            
            nmt_dict = {f['name'].replace('nmt/', ''): f for f in nmt_files}
            llm_dict = {f['name'].replace('llm/', ''): f for f in llm_files}
            
            # Find common files
            common_names = set(nmt_dict.keys()) & set(llm_dict.keys())
            
            for name in sorted(common_names):
                matched_files.append({
                    'filename': name,
                    'nmt_blob': nmt_dict[name]['name'],
                    'llm_blob': llm_dict[name]['name'],
                    'size': nmt_dict[name]['size'],
                    'last_modified': nmt_dict[name]['last_modified']
                })
            
            return {
                'files': matched_files,
                'total_nmt': len(nmt_files),
                'total_llm': len(llm_files),
                'matched': len(matched_files)
            }
        
        except Exception as e:
            logger.error(f"Failed to list translated files: {str(e)}")
            raise

