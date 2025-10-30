"""
Job status tracking service using Azure Table Storage for shared state.

This replaces the in-memory job tracker to enable job tracking across
multiple processes (worker and API).
"""

import logging
from datetime import datetime
from typing import Dict, Any, Optional
from azure.data.tables import TableServiceClient, TableClient
from azure.core.exceptions import ResourceNotFoundError, ResourceExistsError
from app.config import get_settings

logger = logging.getLogger(__name__)


class TableJobTracker:
    """Job tracker using Azure Table Storage for shared state."""
    
    def __init__(self, table_name: str = "translationjobs"):
        """
        Initialize job tracker with Azure Table Storage.
        
        Args:
            table_name: Name of the table to use
        """
        self.settings = get_settings()
        self.table_name = table_name
        
        # Initialize table service client
        if self.settings.azure_storage_connection_string:
            logger.info("✓ Job tracker using CONNECTION STRING (local/Docker mode)")
            self.table_service = TableServiceClient.from_connection_string(
                self.settings.azure_storage_connection_string
            )
        else:
            logger.info(f"✓ Job tracker using AZURE AD for account: {self.settings.azure_storage_account_name}")
            from azure.identity import DefaultAzureCredential
            credential = DefaultAzureCredential(
                exclude_shared_token_cache_credential=True,
                exclude_visual_studio_code_credential=True,
                exclude_environment_credential=False,
                exclude_managed_identity_credential=False,
                exclude_azure_cli_credential=False  # Enable for local dev
            )
            table_url = f"https://{self.settings.azure_storage_account_name}.table.core.windows.net"
            self.table_service = TableServiceClient(
                endpoint=table_url,
                credential=credential
            )
        
        self.table_client = self.table_service.get_table_client(table_name)
        
        # Ensure table exists
        self._ensure_table_exists()
        
        logger.info(f"Job tracker initialized with Azure Table Storage: {table_name}")
    
    def _ensure_table_exists(self) -> None:
        """Ensure the table exists, create if it doesn't."""
        try:
            self.table_service.create_table(self.table_name)
            logger.info(f"Created table: {self.table_name}")
        except ResourceExistsError:
            logger.debug(f"Table already exists: {self.table_name}")
        except Exception as e:
            logger.error(f"Failed to ensure table exists: {str(e)}")
    
    def create_job(
        self,
        job_id: str,
        total_files: int,
        source_container: str,
        target_container: str,
        target_language: str,
        source_language: Optional[str] = None
    ) -> None:
        """
        Create a new job entry in Table Storage.
        
        Args:
            job_id: Unique job identifier
            total_files: Total number of files to process
            source_container: Source container name
            target_container: Target container name
            target_language: Target language code
            source_language: Optional source language code
        """
        entity = {
            'PartitionKey': 'job',  # All jobs in same partition for easy querying
            'RowKey': job_id,
            'job_id': job_id,
            'status': 'queued',
            'total_files': total_files,
            'processed_files': 0,
            'failed_files': 0,
            'source_container': source_container,
            'target_container': target_container,
            'target_language': target_language,
            'source_language': source_language or '',
            'created_at': datetime.utcnow().isoformat(),
            'updated_at': datetime.utcnow().isoformat(),
            'completed_at': '',
            'error': ''
        }
        
        try:
            self.table_client.create_entity(entity)
            logger.info(f"Created job in Table Storage: {job_id} ({total_files} files)")
        except ResourceExistsError:
            logger.warning(f"Job already exists: {job_id}")
        except Exception as e:
            logger.error(f"Failed to create job {job_id}: {str(e)}")
            raise
    
    def update_progress(
        self,
        job_id: str,
        processed: int = 0,
        failed: int = 0,
        status: Optional[str] = None
    ) -> None:
        """
        Update job progress in Table Storage.
        
        Args:
            job_id: Job identifier
            processed: Number of files successfully processed (increment)
            failed: Number of files that failed (increment)
            status: Optional new status
        """
        try:
            # Get current entity
            entity = self.table_client.get_entity(partition_key='job', row_key=job_id)
            
            # Update counters
            if processed > 0:
                entity['processed_files'] = entity.get('processed_files', 0) + processed
            if failed > 0:
                entity['failed_files'] = entity.get('failed_files', 0) + failed
            if status:
                entity['status'] = status
            
            entity['updated_at'] = datetime.utcnow().isoformat()
            
            # Auto-complete if all files processed
            total = entity.get('total_files', 0)
            processed_count = entity.get('processed_files', 0)
            failed_count = entity.get('failed_files', 0)
            
            if processed_count + failed_count >= total and total > 0:
                if entity['status'] != 'completed':
                    entity['status'] = 'completed'
                    entity['completed_at'] = datetime.utcnow().isoformat()
                    logger.info(f"Job completed: {job_id} ({processed_count}/{total} succeeded)")
            
            # Update entity
            self.table_client.update_entity(entity, mode='replace')
            logger.debug(f"Updated job progress: {job_id} (processed: {processed}, failed: {failed})")
            
        except ResourceNotFoundError:
            logger.warning(f"Job not found for update: {job_id}")
        except Exception as e:
            logger.error(f"Failed to update job {job_id}: {str(e)}")
            # Don't raise - progress updates shouldn't break the worker
    
    def mark_completed(self, job_id: str, error: Optional[str] = None) -> None:
        """
        Mark job as completed or failed.
        
        Args:
            job_id: Job identifier
            error: Optional error message if job failed
        """
        try:
            entity = self.table_client.get_entity(partition_key='job', row_key=job_id)
            
            entity['status'] = 'failed' if error else 'completed'
            entity['completed_at'] = datetime.utcnow().isoformat()
            entity['updated_at'] = datetime.utcnow().isoformat()
            if error:
                entity['error'] = error
            
            self.table_client.update_entity(entity, mode='replace')
            logger.info(f"Job marked as {entity['status']}: {job_id}")
            
        except ResourceNotFoundError:
            logger.warning(f"Job not found: {job_id}")
        except Exception as e:
            logger.error(f"Failed to mark job complete {job_id}: {str(e)}")
    
    def get_status(self, job_id: str) -> Optional[Dict[str, Any]]:
        """
        Get job status from Table Storage.
        
        Args:
            job_id: Job identifier
            
        Returns:
            Job status dictionary or None if not found
        """
        try:
            entity = self.table_client.get_entity(partition_key='job', row_key=job_id)
            
            # Convert Table Storage entity to dict
            return {
                'job_id': entity.get('job_id', job_id),
                'status': entity.get('status', 'unknown'),
                'total_files': entity.get('total_files', 0),
                'processed_files': entity.get('processed_files', 0),
                'failed_files': entity.get('failed_files', 0),
                'source_container': entity.get('source_container', ''),
                'target_container': entity.get('target_container', ''),
                'target_language': entity.get('target_language', ''),
                'source_language': entity.get('source_language', '') or None,
                'created_at': entity.get('created_at', ''),
                'updated_at': entity.get('updated_at', ''),
                'completed_at': entity.get('completed_at', '') or None,
                'error': entity.get('error', '') or None,
                'message': None
            }
            
        except ResourceNotFoundError:
            logger.warning(f"Job not found: {job_id}")
            return None
        except Exception as e:
            logger.error(f"Failed to get job status {job_id}: {str(e)}")
            return None
    
    def get_all_jobs(self, limit: int = 100) -> list[Dict[str, Any]]:
        """
        Get all jobs from Table Storage.
        
        Args:
            limit: Maximum number of jobs to return
            
        Returns:
            List of job status dictionaries
        """
        try:
            # Query all jobs in the partition
            query = f"PartitionKey eq 'job'"
            entities = self.table_client.query_entities(query, results_per_page=limit)
            
            jobs = []
            for entity in entities:
                jobs.append({
                    'job_id': entity.get('job_id', entity.get('RowKey')),
                    'status': entity.get('status', 'unknown'),
                    'total_files': entity.get('total_files', 0),
                    'processed_files': entity.get('processed_files', 0),
                    'failed_files': entity.get('failed_files', 0),
                    'source_container': entity.get('source_container', ''),
                    'target_container': entity.get('target_container', ''),
                    'target_language': entity.get('target_language', ''),
                    'source_language': entity.get('source_language', '') or None,
                    'created_at': entity.get('created_at', ''),
                    'updated_at': entity.get('updated_at', ''),
                    'completed_at': entity.get('completed_at', '') or None,
                    'error': entity.get('error', '') or None,
                    'message': None
                })
            
            # Sort by created_at descending
            jobs.sort(key=lambda x: x.get('created_at', ''), reverse=True)
            return jobs[:limit]
            
        except Exception as e:
            logger.error(f"Failed to get all jobs: {str(e)}")
            return []
    
    def delete_job(self, job_id: str) -> bool:
        """
        Delete a job from Table Storage.
        
        Args:
            job_id: Job identifier
            
        Returns:
            True if job was deleted, False if not found
        """
        try:
            self.table_client.delete_entity(partition_key='job', row_key=job_id)
            logger.info(f"Deleted job: {job_id}")
            return True
        except ResourceNotFoundError:
            logger.warning(f"Job not found for deletion: {job_id}")
            return False
        except Exception as e:
            logger.error(f"Failed to delete job {job_id}: {str(e)}")
            return False
    
    def cleanup_old_jobs(self, max_age_hours: int = 24) -> int:
        """
        Clean up jobs older than specified hours.
        
        Args:
            max_age_hours: Maximum age in hours
            
        Returns:
            Number of jobs deleted
        """
        from datetime import timedelta
        
        cutoff_time = datetime.utcnow() - timedelta(hours=max_age_hours)
        cutoff_str = cutoff_time.isoformat()
        
        try:
            # Query completed jobs older than cutoff
            query = f"PartitionKey eq 'job' and completed_at lt '{cutoff_str}'"
            entities = self.table_client.query_entities(query)
            
            deleted_count = 0
            for entity in entities:
                try:
                    self.table_client.delete_entity(entity)
                    deleted_count += 1
                except Exception as e:
                    logger.error(f"Failed to delete old job {entity.get('RowKey')}: {str(e)}")
            
            if deleted_count > 0:
                logger.info(f"Cleaned up {deleted_count} old jobs")
            
            return deleted_count
            
        except Exception as e:
            logger.error(f"Failed to cleanup old jobs: {str(e)}")
            return 0


# Global job tracker instance
_job_tracker: Optional[TableJobTracker] = None


def get_job_tracker() -> TableJobTracker:
    """Get or create the global job tracker instance."""
    global _job_tracker
    if _job_tracker is None:
        _job_tracker = TableJobTracker()
    return _job_tracker

