#!/usr/bin/env python3
"""
Load sample translation data into Azure Storage for testing and demonstration.
"""

import json
import os
import sys
from pathlib import Path
from datetime import datetime
from typing import List, Dict, Any

# Add parent directory to path to import config
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "src" / "backend"))

try:
    from azure.storage.blob import BlobServiceClient, ContainerClient
    from azure.data.tables import TableServiceClient, TableEntity
    from azure.identity import DefaultAzureCredential
    from dotenv import load_dotenv
except ImportError as e:
    print(f"Error: Missing required package. Run: pip install -r requirements.txt")
    print(f"Details: {e}")
    sys.exit(1)

# Load environment variables
load_dotenv()

# Configuration
STORAGE_CONNECTION_STRING = os.getenv("AZURE_STORAGE_CONNECTION_STRING")
CONTAINER_NAME = os.getenv("AZURE_STORAGE_CONTAINER_NAME", "translations")
SAMPLES_DIR = Path(__file__).parent.parent / "samples"


def load_sample_data() -> List[Dict[str, Any]]:
    """Load sample texts from JSON file."""
    sample_file = SAMPLES_DIR / "sample_texts.json"
    
    if not sample_file.exists():
        print(f"Error: Sample file not found: {sample_file}")
        sys.exit(1)
    
    with open(sample_file, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    print(f"✓ Loaded {len(data)} sample texts")
    return data


def upload_to_blob_storage(samples: List[Dict[str, Any]]):
    """Upload sample data to Azure Blob Storage."""
    if not STORAGE_CONNECTION_STRING:
        print("⚠ Warning: AZURE_STORAGE_CONNECTION_STRING not set. Skipping blob upload.")
        return
    
    try:
        # Create blob service client
        blob_service_client = BlobServiceClient.from_connection_string(STORAGE_CONNECTION_STRING)
        
        # Create container if it doesn't exist
        try:
            container_client = blob_service_client.create_container(CONTAINER_NAME)
            print(f"✓ Created container: {CONTAINER_NAME}")
        except Exception:
            container_client = blob_service_client.get_container_client(CONTAINER_NAME)
            print(f"✓ Using existing container: {CONTAINER_NAME}")
        
        # Upload samples as JSON blob
        blob_name = f"samples/sample_texts_{datetime.utcnow().strftime('%Y%m%d')}.json"
        blob_client = container_client.get_blob_client(blob_name)
        
        data_json = json.dumps(samples, ensure_ascii=False, indent=2)
        blob_client.upload_blob(data_json, overwrite=True)
        
        print(f"✓ Uploaded samples to blob: {blob_name}")
        
    except Exception as e:
        print(f"✗ Error uploading to blob storage: {e}")


def upload_to_table_storage(samples: List[Dict[str, Any]]):
    """Upload sample data to Azure Table Storage for history tracking."""
    if not STORAGE_CONNECTION_STRING:
        print("⚠ Warning: AZURE_STORAGE_CONNECTION_STRING not set. Skipping table upload.")
        return
    
    try:
        # Create table service client
        table_service_client = TableServiceClient.from_connection_string(STORAGE_CONNECTION_STRING)
        
        # Create table if it doesn't exist
        table_name = "SampleTranslations"
        try:
            table_client = table_service_client.create_table(table_name)
            print(f"✓ Created table: {table_name}")
        except Exception:
            table_client = table_service_client.get_table_client(table_name)
            print(f"✓ Using existing table: {table_name}")
        
        # Upload each sample as a table entity
        for sample in samples:
            entity: TableEntity = {
                "PartitionKey": sample.get("language", "unknown"),
                "RowKey": str(sample["id"]),
                "Text": sample["text"],
                "Language": sample.get("language", "unknown"),
                "Category": sample.get("category", "general"),
                "CreatedAt": datetime.utcnow().isoformat(),
            }
            
            table_client.upsert_entity(entity)
        
        print(f"✓ Uploaded {len(samples)} entities to table: {table_name}")
        
    except Exception as e:
        print(f"✗ Error uploading to table storage: {e}")


def main():
    """Main function to load and upload sample data."""
    print("=" * 60)
    print("Azure Translator Solution Accelerator - Load Sample Data")
    print("=" * 60)
    print()
    
    # Check configuration
    if not STORAGE_CONNECTION_STRING:
        print("⚠ Warning: AZURE_STORAGE_CONNECTION_STRING not configured.")
        print("Sample data will be loaded but not uploaded to Azure Storage.")
        print()
    
    # Load sample data
    samples = load_sample_data()
    
    # Upload to storage
    upload_to_blob_storage(samples)
    upload_to_table_storage(samples)
    
    print()
    print("=" * 60)
    print("✓ Sample data loading complete!")
    print("=" * 60)


if __name__ == "__main__":
    main()

