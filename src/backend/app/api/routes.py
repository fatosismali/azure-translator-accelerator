"""
API routes for Azure Translator Service.
"""

import logging
import uuid
from typing import Dict, Any
from fastapi import APIRouter, Depends, HTTPException, status

from app.config import Settings, get_settings
from app.api.models import (
    TranslateRequest,
    TranslateResponse,
    TranslateLLMRequest,
    CompareTranslationRequest,
    DetectRequest,
    DetectResponse,
    TransliterateRequest,
    TransliterateResponse,
    DictionaryLookupRequest,
    DictionaryLookupResponse,
    DictionaryExamplesRequest,
    DictionaryExamplesResponse,
    LanguagesResponse,
    ErrorResponse,
)
from app.services.translator_service import TranslatorService

logger = logging.getLogger(__name__)

router = APIRouter(tags=["Translator"])


def get_translator_service(settings: Settings = Depends(get_settings)) -> TranslatorService:
    """Dependency injection for TranslatorService."""
    return TranslatorService(settings)


@router.post("/translate", response_model=TranslateResponse, responses={
    400: {"model": ErrorResponse},
    429: {"model": ErrorResponse},
    500: {"model": ErrorResponse},
})
async def translate_text(
    request: TranslateRequest,
    translator: TranslatorService = Depends(get_translator_service),
) -> TranslateResponse:
    """
    Translate text to one or more target languages.
    
    Supports:
    - Single or multiple texts
    - Multiple target languages
    - Automatic language detection
    - Text type (plain/html)
    - Profanity filtering
    
    Example:
    ```json
    {
        "text": "Hello, world!",
        "to": ["es", "fr", "de"],
        "from": "en"
    }
    ```
    """
    try:
        request_id = str(uuid.uuid4())
        logger.info(f"Translation request {request_id}: {request.to}")
        
        result = await translator.translate(
            text=request.text,
            to=request.to,
            from_lang=request.from_lang,
            text_type=request.text_type,
            category=request.category,
            profanity_action=request.profanity_action,
            profanity_marker=request.profanity_marker,
            include_alignment=request.include_alignment,
            include_sentence_length=request.include_sentence_length,
            suggested_from=request.suggested_from,
            from_script=request.from_script,
            to_script=request.to_script,
            allow_fallback=request.allow_fallback,
        )
        
        return TranslateResponse(translations=result, request_id=request_id)
    
    except Exception as e:
        logger.error(f"Translation error: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


@router.post("/translate/llm", response_model=TranslateResponse, responses={
    400: {"model": ErrorResponse},
    429: {"model": ErrorResponse},
    500: {"model": ErrorResponse},
})
async def translate_with_llm(
    request: TranslateLLMRequest,
    translator: TranslatorService = Depends(get_translator_service),
) -> TranslateResponse:
    """
    Translate text using LLM models (GPT-4o-mini or GPT-4o) with 2025-05-01-preview API.
    
    Features:
    - Large Language Model translation (GPT-4o-mini or GPT-4o)
    - Tone variants (formal, informal, neutral)
    - Gender-specific translations (male, female, neutral)
    - Adaptive custom translation with reference examples
    - Up to 50 texts, max 5000 chars each
    
    Note: Requires Azure AI Foundry resource for LLM models.
    
    Example:
    ```json
    {
        "text": "Hello, how are you?",
        "to": ["es"],
        "from": "en",
        "model": "gpt-4o-mini",
        "tone": "formal"
    }
    ```
    """
    try:
        request_id = str(uuid.uuid4())
        logger.info(f"LLM Translation request {request_id}: model={request.model}, to={request.to}")
        
        result = await translator.translate_with_llm(
            text=request.text,
            to=request.to,
            from_lang=request.from_lang,
            model=request.model,
            tone=request.tone,
            gender=request.gender,
            reference_translations=request.reference_translations,
            text_type=request.text_type,
            profanity_action=request.profanity_action,
        )
        
        return TranslateResponse(translations=result, request_id=request_id)
    
    except Exception as e:
        logger.error(f"LLM Translation error: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


@router.post("/translate/compare", responses={
    400: {"model": ErrorResponse},
    500: {"model": ErrorResponse},
})
async def compare_translations(
    request: CompareTranslationRequest,
    translator: TranslatorService = Depends(get_translator_service),
) -> Dict[str, Any]:
    """
    Compare NMT (Neural Machine Translation) and LLM translations side-by-side.
    
    Returns both translations with metadata for comparison:
    - NMT: Standard neural translation (fast, cost-effective)
    - LLM: GPT-4o-mini/GPT-4o translation (high-quality, contextual)
    
    Example:
    ```json
    {
        "text": "The meeting will take place tomorrow.",
        "to": "es",
        "from": "en",
        "llm_model": "gpt-4o-mini",
        "tone": "formal"
    }
    ```
    """
    try:
        request_id = str(uuid.uuid4())
        logger.info(f"Compare request {request_id}: NMT vs {request.llm_model}")
        
        # Run both translations in parallel
        import asyncio
        
        nmt_task = translator.translate(
            text=request.text,
            to=[request.to],
            from_lang=request.from_lang,
        )
        
        llm_task = translator.translate_with_llm(
            text=request.text,
            to=[request.to],
            from_lang=request.from_lang,
            model=request.llm_model,
            tone=request.tone,
            gender=request.gender,
        )
        
        nmt_result, llm_result = await asyncio.gather(nmt_task, llm_task, return_exceptions=True)
        
        # Handle errors
        nmt_error = None
        llm_error = None
        
        if isinstance(nmt_result, Exception):
            nmt_error = str(nmt_result)
            nmt_result = None
        
        if isinstance(llm_result, Exception):
            llm_error = str(llm_result)
            llm_result = None
        
        return {
            "request_id": request_id,
            "source_text": request.text,
            "source_language": request.from_lang or "auto",
            "target_language": request.to,
            "nmt": {
                "translation": nmt_result[0] if nmt_result else None,
                "error": nmt_error,
                "model": "Neural Machine Translation",
                "api_version": "3.0",
            },
            "llm": {
                "translation": llm_result[0] if llm_result else None,
                "error": llm_error,
                "model": request.llm_model,
                "api_version": "2025-05-01-preview",
                "tone": request.tone,
                "gender": request.gender,
            }
        }
    
    except Exception as e:
        logger.error(f"Compare error: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


@router.post("/detect", response_model=DetectResponse, responses={
    400: {"model": ErrorResponse},
    500: {"model": ErrorResponse},
})
async def detect_language(
    request: DetectRequest,
    translator: TranslatorService = Depends(get_translator_service),
) -> DetectResponse:
    """
    Detect the language of input text.
    
    Returns language code, confidence score, and support information.
    
    Example:
    ```json
    {
        "text": "Bonjour le monde"
    }
    ```
    """
    try:
        request_id = str(uuid.uuid4())
        logger.info(f"Language detection request {request_id}")
        
        result = await translator.detect(text=request.text)
        
        return DetectResponse(detections=result, request_id=request_id)
    
    except Exception as e:
        logger.error(f"Detection error: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


@router.post("/transliterate", response_model=TransliterateResponse, responses={
    400: {"model": ErrorResponse},
    500: {"model": ErrorResponse},
})
async def transliterate_text(
    request: TransliterateRequest,
    translator: TranslatorService = Depends(get_translator_service),
) -> TransliterateResponse:
    """
    Transliterate text from one script to another.
    
    Example (Arabic to Latin):
    ```json
    {
        "text": "مرحبا",
        "language": "ar",
        "from_script": "Arab",
        "to_script": "Latn"
    }
    ```
    """
    try:
        request_id = str(uuid.uuid4())
        logger.info(f"Transliteration request {request_id}: {request.from_script} -> {request.to_script}")
        
        result = await translator.transliterate(
            text=request.text,
            language=request.language,
            from_script=request.from_script,
            to_script=request.to_script,
        )
        
        return TransliterateResponse(results=result, request_id=request_id)
    
    except Exception as e:
        logger.error(f"Transliteration error: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


@router.post("/dictionary/lookup", response_model=DictionaryLookupResponse, responses={
    400: {"model": ErrorResponse},
    500: {"model": ErrorResponse},
})
async def dictionary_lookup(
    request: DictionaryLookupRequest,
    translator: TranslatorService = Depends(get_translator_service),
) -> DictionaryLookupResponse:
    """
    Look up alternative translations for a word or phrase.
    
    Example:
    ```json
    {
        "text": "hello",
        "from": "en",
        "to": "es"
    }
    ```
    """
    try:
        request_id = str(uuid.uuid4())
        logger.info(f"Dictionary lookup request {request_id}: {request.from_lang} -> {request.to}")
        
        result = await translator.dictionary_lookup(
            text=request.text,
            from_lang=request.from_lang,
            to=request.to,
        )
        
        return DictionaryLookupResponse(results=result, request_id=request_id)
    
    except Exception as e:
        logger.error(f"Dictionary lookup error: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


@router.post("/dictionary/examples", response_model=DictionaryExamplesResponse, responses={
    400: {"model": ErrorResponse},
    500: {"model": ErrorResponse},
})
async def dictionary_examples(
    request: DictionaryExamplesRequest,
    translator: TranslatorService = Depends(get_translator_service),
) -> DictionaryExamplesResponse:
    """
    Get usage examples for a word or phrase translation.
    
    Example:
    ```json
    {
        "text": "hello",
        "translation": "hola",
        "from": "en",
        "to": "es"
    }
    ```
    """
    try:
        request_id = str(uuid.uuid4())
        logger.info(f"Dictionary examples request {request_id}")
        
        result = await translator.dictionary_examples(
            text=request.text,
            translation=request.translation,
            from_lang=request.from_lang,
            to=request.to,
        )
        
        return DictionaryExamplesResponse(results=result, request_id=request_id)
    
    except Exception as e:
        logger.error(f"Dictionary examples error: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


@router.post("/dictionary/compare", responses={
    400: {"model": ErrorResponse},
    500: {"model": ErrorResponse},
})
async def compare_dictionary(
    request: DictionaryLookupRequest,
    translator: TranslatorService = Depends(get_translator_service),
) -> Dict[str, Any]:
    """
    Compare NMT and LLM dictionary lookups side-by-side.
    
    Returns both dictionary results with metadata for comparison:
    - NMT: Standard dictionary lookup (specific alternatives, part-of-speech)
    - LLM: GPT-4o-mini generated alternatives (tone-based variations)
    
    Example:
    ```json
    {
        "text": "hello",
        "from": "en",
        "to": "es"
    }
    ```
    """
    try:
        request_id = str(uuid.uuid4())
        logger.info(f"Dictionary compare request {request_id}: {request.text}")
        
        # Run both dictionary lookups in parallel
        import asyncio
        
        nmt_task = translator.dictionary_lookup(
            text=request.text,
            from_lang=request.from_lang,
            to=request.to,
        )
        
        llm_task = translator.dictionary_lookup_llm(
            text=request.text,
            from_lang=request.from_lang,
            to=request.to,
        )
        
        nmt_result, llm_result = await asyncio.gather(nmt_task, llm_task, return_exceptions=True)
        
        # Handle errors
        nmt_error = None
        llm_error = None
        
        if isinstance(nmt_result, Exception):
            nmt_error = str(nmt_result)
            nmt_result = None
        
        if isinstance(llm_result, Exception):
            llm_error = str(llm_result)
            llm_result = None
        
        return {
            "request_id": request_id,
            "text": request.text,
            "from_lang": request.from_lang,
            "to_lang": request.to,
            "nmt": {
                "result": nmt_result,
                "error": nmt_error,
                "method": "Dictionary Lookup API",
                "api_version": "3.0",
            },
            "llm": {
                "result": llm_result,
                "error": llm_error,
                "method": "LLM-Generated Alternatives (GPT-4o-mini)",
                "api_version": "2025-05-01-preview",
                "note": "Uses tone variations (formal/informal/neutral)",
            }
        }
    
    except Exception as e:
        logger.error(f"Dictionary compare error: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


@router.get("/languages", response_model=Dict[str, Any], responses={
    500: {"model": ErrorResponse},
})
async def get_supported_languages(
    scope: str = "translation",
    translator: TranslatorService = Depends(get_translator_service),
) -> Dict[str, Any]:
    """
    Get list of supported languages for translation, transliteration, or dictionary.
    
    Query parameters:
    - scope: translation, transliteration, or dictionary (default: translation)
    
    Example response:
    ```json
    {
        "translation": {
            "en": {"name": "English", "nativeName": "English", "dir": "ltr"},
            "es": {"name": "Spanish", "nativeName": "Español", "dir": "ltr"}
        }
    }
    ```
    """
    try:
        logger.info(f"Languages request for scope: {scope}")
        
        result = await translator.get_languages(scope=scope)
        
        return result
    
    except Exception as e:
        logger.error(f"Get languages error: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


@router.get("/languages/{scope}", response_model=Dict[str, Any])
async def get_languages_by_scope(
    scope: str,
    translator: TranslatorService = Depends(get_translator_service),
) -> Dict[str, Any]:
    """
    Get supported languages for a specific scope.
    
    Path parameters:
    - scope: translation, transliteration, or dictionary
    """
    return await get_supported_languages(scope=scope, translator=translator)



# ============================================================================
# BATCH TRANSLATION ENDPOINTS
# ============================================================================

from app.services.storage_service import StorageService
from app.services.queue_service import QueueService
from app.services.batch_service import BatchTranslationService
from app.api.models import (
    BatchJobRequest,
    BatchJobResponse,
    BatchJobStatusResponse,
    TranslatedFilesResponse,
    FileTranslationContent,
    RatingRequest,
    RatingResponse,
    RatingStats,
)


def get_storage_service() -> StorageService:
    """Dependency injection for storage service."""
    return StorageService()


def get_queue_service() -> QueueService:
    """Dependency injection for queue service."""
    return QueueService()


def get_batch_service(
    storage: StorageService = Depends(get_storage_service),
    queue: QueueService = Depends(get_queue_service),
    translator: TranslatorService = Depends(get_translator_service),
) -> BatchTranslationService:
    """Dependency injection for batch service."""
    return BatchTranslationService(storage, queue, translator)


@router.get("/batch/containers")
async def list_containers(
    storage: StorageService = Depends(get_storage_service),
) -> Dict[str, Any]:
    """
    List all blob storage containers.
    
    Returns list of container names available for batch translation.
    """
    try:
        containers = storage.list_containers()
        return {
            "containers": containers,
            "total": len(containers)
        }
    except Exception as e:
        logger.error(f"Failed to list containers: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


@router.get("/batch/containers/{container_name}/files")
async def list_container_files(
    container_name: str,
    storage: StorageService = Depends(get_storage_service),
) -> Dict[str, Any]:
    """
    List text files in a container.
    
    Path parameters:
    - container_name: Container name to list files from
    """
    try:
        files = storage.list_blobs(container_name)
        return {
            "container": container_name,
            "files": files,
            "total": len(files)
        }
    except Exception as e:
        logger.error(f"Failed to list files: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


@router.post("/batch/jobs", response_model=BatchJobResponse)
async def start_batch_job(
    request: BatchJobRequest,
    batch_service: BatchTranslationService = Depends(get_batch_service),
) -> BatchJobResponse:
    """
    Start a new batch translation job.
    
    This will:
    1. List all .txt files from source container
    2. Add each file to the translation queue
    3. Process files with both NMT and LLM
    4. Store results in target container under /nmt and /llm directories
    
    Example:
    ```json
    {
        "source_container": "source-texts",
        "target_container": "translations",
        "target_language": "es",
        "source_language": "en"
    }
    ```
    """
    try:
        result = await batch_service.start_batch_job(
            source_container=request.source_container,
            target_container=request.target_container,
            target_language=request.target_language,
            source_language=request.source_language,
            prefix=request.prefix
        )
        return BatchJobResponse(**result)
    except Exception as e:
        logger.error(f"Failed to start batch job: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


@router.get("/batch/jobs/{job_id}", response_model=BatchJobStatusResponse)
async def get_job_status(
    job_id: str,
    batch_service: BatchTranslationService = Depends(get_batch_service),
) -> BatchJobStatusResponse:
    """
    Get status of a batch translation job.
    
    Path parameters:
    - job_id: Job ID to check status for
    """
    try:
        status_info = batch_service.get_job_status(job_id)
        return BatchJobStatusResponse(**status_info)
    except Exception as e:
        logger.error(f"Failed to get job status: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


@router.get("/batch/translations/{container_name}", response_model=TranslatedFilesResponse)
async def list_translated_files(
    container_name: str,
    batch_service: BatchTranslationService = Depends(get_batch_service),
) -> TranslatedFilesResponse:
    """
    List all translated files in a container.
    
    Returns matched pairs of NMT and LLM translations.
    
    Path parameters:
    - container_name: Target container name with translations
    """
    try:
        result = batch_service.list_translated_files(container_name)
        return TranslatedFilesResponse(**result)
    except Exception as e:
        logger.error(f"Failed to list translated files: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


@router.get("/batch/translations/{container_name}/file", response_model=FileTranslationContent)
async def get_file_translations(
    container_name: str,
    filename: str,
    storage: StorageService = Depends(get_storage_service),
) -> FileTranslationContent:
    """
    Get NMT and LLM translations for a specific file.
    
    Path parameters:
    - container_name: Container name
    
    Query parameters:
    - filename: Base filename (without nmt/llm prefix)
    """
    try:
        nmt_blob = f"nmt/{filename}"
        llm_blob = f"llm/{filename}"
        
        nmt_content = storage.read_blob(container_name, nmt_blob)
        llm_content = storage.read_blob(container_name, llm_blob)
        
        return FileTranslationContent(
            filename=filename,
            nmt_content=nmt_content,
            llm_content=llm_content,
            nmt_blob=nmt_blob,
            llm_blob=llm_blob
        )
    except Exception as e:
        logger.error(f"Failed to get file translations: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


@router.get("/batch/evaluate/{source_container}/{target_container}")
async def get_evaluation_data(
    source_container: str,
    target_container: str,
    storage: StorageService = Depends(get_storage_service),
) -> Dict[str, Any]:
    """
    Get all files with source content, NMT, and LLM translations for 3-pane evaluation view.
    
    Path parameters:
    - source_container: Source container with original files
    - target_container: Target container with nmt/ and llm/ translations
    """
    try:
        # Get all NMT and LLM files
        nmt_files = storage.list_blobs(target_container, prefix="nmt/")
        llm_files = storage.list_blobs(target_container, prefix="llm/")
        
        # Create filename mappings
        nmt_map = {blob['name'].replace('nmt/', ''): blob['name'] for blob in nmt_files}
        llm_map = {blob['name'].replace('llm/', ''): blob['name'] for blob in llm_files}
        
        # Get files that have both translations
        common_files = set(nmt_map.keys()) & set(llm_map.keys())
        
        if not common_files:
            return {
                "source_container": source_container,
                "target_container": target_container,
                "files": [],
                "total": 0
            }
        
        # Load all file contents
        evaluation_data = []
        for filename in sorted(common_files):
            try:
                source_content = storage.read_blob(source_container, filename)
                nmt_content = storage.read_blob(target_container, nmt_map[filename])
                llm_content = storage.read_blob(target_container, llm_map[filename])
                
                evaluation_data.append({
                    "filename": filename,
                    "source_content": source_content,
                    "nmt_content": nmt_content,
                    "llm_content": llm_content
                })
            except Exception as e:
                logger.warning(f"Failed to load {filename}: {str(e)}")
                continue
        
        return {
            "source_container": source_container,
            "target_container": target_container,
            "files": evaluation_data,
            "total": len(evaluation_data)
        }
    
    except Exception as e:
        logger.error(f"Error getting evaluation data: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


# ============================================================================
# RATING ENDPOINTS
# ============================================================================

# Simple in-memory storage for ratings (in production, use Azure Table Storage or Database)
ratings_store: Dict[str, Dict[str, Any]] = {}


@router.post("/ratings", response_model=RatingResponse)
async def submit_rating(request: RatingRequest) -> RatingResponse:
    """
    Submit a rating for a translation pair.
    
    Example:
    ```json
    {
        "filename": "document1.txt",
        "container": "translations",
        "nmt_blob": "nmt/document1.txt",
        "llm_blob": "llm/document1.txt",
        "preferred": "llm",
        "comments": "LLM translation sounds more natural"
    }
    ```
    """
    try:
        rating_id = str(uuid.uuid4())
        
        ratings_store[rating_id] = {
            "rating_id": rating_id,
            "filename": request.filename,
            "container": request.container,
            "nmt_blob": request.nmt_blob,
            "llm_blob": request.llm_blob,
            "preferred": request.preferred,
            "comments": request.comments,
            "created_at": datetime.utcnow().isoformat()
        }
        
        logger.info(f"Rating submitted: {rating_id} - {request.preferred} preferred for {request.filename}")
        
        return RatingResponse(
            success=True,
            message="Rating submitted successfully",
            rating_id=rating_id
        )
    except Exception as e:
        logger.error(f"Failed to submit rating: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


@router.get("/ratings/stats", response_model=RatingStats)
async def get_rating_stats() -> RatingStats:
    """
    Get statistics for translation ratings.
    
    Returns counts and percentages of NMT vs LLM preferences.
    """
    try:
        total = len(ratings_store)
        
        if total == 0:
            return RatingStats(
                total_ratings=0,
                nmt_preferred=0,
                llm_preferred=0,
                nmt_percentage=0.0,
                llm_percentage=0.0
            )
        
        nmt_count = sum(1 for r in ratings_store.values() if r['preferred'] == 'nmt')
        llm_count = sum(1 for r in ratings_store.values() if r['preferred'] == 'llm')
        
        return RatingStats(
            total_ratings=total,
            nmt_preferred=nmt_count,
            llm_preferred=llm_count,
            nmt_percentage=(nmt_count / total) * 100,
            llm_percentage=(llm_count / total) * 100
        )
    except Exception as e:
        logger.error(f"Failed to get rating stats: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


@router.get("/ratings/list")
async def list_ratings() -> Dict[str, Any]:
    """List all ratings."""
    return {
        "ratings": list(ratings_store.values()),
        "total": len(ratings_store)
    }
