"""
Pydantic models for API request/response validation.
"""

from typing import List, Optional, Dict, Any, Union
from pydantic import BaseModel, Field, field_validator


class TranslateRequest(BaseModel):
    """Request model for translation."""
    text: Union[str, List[str]] = Field(..., description="Text or list of texts to translate")
    to: List[str] = Field(..., min_length=1, description="Target language codes (ISO 639-1)")
    from_lang: Optional[str] = Field(
        default=None,
        alias="from",
        description="Source language code (auto-detect if not provided)"
    )
    text_type: Optional[str] = Field(default="plain", description="Text type: plain or html")
    category: Optional[str] = Field(default="general", description="Translation category")
    profanity_action: Optional[str] = Field(default=None, description="Profanity handling")
    profanity_marker: Optional[str] = Field(default=None, description="Profanity marker")
    include_alignment: Optional[bool] = Field(default=False, description="Include alignment info")
    include_sentence_length: Optional[bool] = Field(default=False, description="Include sentence lengths")
    suggested_from: Optional[str] = Field(default=None, description="Suggested source language")
    from_script: Optional[str] = Field(default=None, description="Source script")
    to_script: Optional[str] = Field(default=None, description="Target script")
    allow_fallback: Optional[bool] = Field(default=True, description="Allow fallback")

    @field_validator('text')
    @classmethod
    def validate_text(cls, v):
        """Validate text input."""
        if isinstance(v, str):
            if not v.strip():
                raise ValueError("Text cannot be empty")
            if len(v) > 50000:
                raise ValueError("Text too long (max 50,000 characters)")
        elif isinstance(v, list):
            if len(v) == 0:
                raise ValueError("Text list cannot be empty")
            if len(v) > 100:
                raise ValueError("Too many texts (max 100)")
            for text in v:
                if not text.strip():
                    raise ValueError("Empty text in list")
        return v
    
    class Config:
        populate_by_name = True


class TranslateLLMRequest(BaseModel):
    """Request model for LLM translation (2025-05-01-preview API)."""
    text: Union[str, List[str]] = Field(..., description="Text or list of texts to translate (max 50 items, 5000 chars each)")
    to: List[str] = Field(..., min_length=1, description="Target language codes (ISO 639-1)")
    from_lang: Optional[str] = Field(
        default=None,
        alias="from",
        description="Source language code (auto-detect if not provided)"
    )
    model: str = Field(default="gpt-4o-mini", description="LLM model: gpt-4o-mini or gpt-4o")
    tone: Optional[str] = Field(default=None, description="Tone variant: formal, informal, neutral")
    gender: Optional[str] = Field(default=None, description="Gender-specific: male, female, neutral")
    reference_translations: Optional[List[str]] = Field(default=None, description="Up to 5 reference translations")
    text_type: Optional[str] = Field(default="plain", description="Text type: plain or html")
    profanity_action: Optional[str] = Field(default=None, description="Profanity handling")

    @field_validator('text')
    @classmethod
    def validate_text(cls, v):
        """Validate text input for LLM (stricter limits)."""
        if isinstance(v, str):
            if not v.strip():
                raise ValueError("Text cannot be empty")
            if len(v) > 5000:
                raise ValueError("Text too long for LLM (max 5,000 characters)")
        elif isinstance(v, list):
            if len(v) == 0:
                raise ValueError("Text list cannot be empty")
            if len(v) > 50:
                raise ValueError("Too many texts for LLM (max 50)")
            for text in v:
                if not text.strip():
                    raise ValueError("Empty text in list")
                if len(text) > 5000:
                    raise ValueError("Text item too long for LLM (max 5,000 characters)")
        return v
    
    @field_validator('model')
    @classmethod
    def validate_model(cls, v):
        """Validate LLM model selection."""
        allowed_models = ["gpt-4o-mini", "gpt-4o"]
        if v not in allowed_models:
            raise ValueError(f"Model must be one of: {', '.join(allowed_models)}")
        return v
    
    @field_validator('reference_translations')
    @classmethod
    def validate_references(cls, v):
        """Validate reference translations."""
        if v and len(v) > 5:
            raise ValueError("Maximum 5 reference translations allowed")
        return v
    
    class Config:
        populate_by_name = True


class CompareTranslationRequest(BaseModel):
    """Request model for comparing NMT and LLM translations side-by-side."""
    text: str = Field(..., description="Text to translate")
    to: str = Field(..., description="Target language code")
    from_lang: Optional[str] = Field(
        default=None,
        alias="from",
        description="Source language code (auto-detect if not provided)"
    )
    llm_model: str = Field(default="gpt-4o-mini", description="LLM model to use")
    tone: Optional[str] = Field(default=None, description="Tone for LLM translation")
    gender: Optional[str] = Field(default=None, description="Gender for LLM translation")
    
    class Config:
        populate_by_name = True


class Translation(BaseModel):
    """Single translation result."""
    text: str
    to: str
    
class TranslationItem(BaseModel):
    """Translation item with detected language."""
    detected_language: Optional[Dict[str, Any]] = None
    translations: List[Translation]


class TranslateResponse(BaseModel):
    """Response model for translation."""
    translations: List[TranslationItem]
    request_id: Optional[str] = None


class DetectRequest(BaseModel):
    """Request model for language detection."""
    text: Union[str, List[str]] = Field(..., description="Text or list of texts to detect language")
    
    @field_validator('text')
    @classmethod
    def validate_text(cls, v):
        """Validate text input."""
        if isinstance(v, str):
            if not v.strip():
                raise ValueError("Text cannot be empty")
        elif isinstance(v, list):
            if len(v) == 0:
                raise ValueError("Text list cannot be empty")
            for text in v:
                if not text.strip():
                    raise ValueError("Empty text in list")
        return v


class DetectedLanguage(BaseModel):
    """Detected language information."""
    language: str
    score: float
    is_translation_supported: bool
    is_transliteration_supported: bool
    alternatives: Optional[List[Dict[str, Any]]] = None


class DetectResponse(BaseModel):
    """Response model for language detection."""
    detections: List[DetectedLanguage]
    request_id: Optional[str] = None


class TransliterateRequest(BaseModel):
    """Request model for transliteration."""
    text: Union[str, List[str]] = Field(..., description="Text to transliterate")
    language: str = Field(..., description="Language code")
    from_script: str = Field(..., description="Source script")
    to_script: str = Field(..., description="Target script")


class TransliterateResponse(BaseModel):
    """Response model for transliteration."""
    results: List[Dict[str, Any]]
    request_id: Optional[str] = None


class DictionaryLookupRequest(BaseModel):
    """Request model for dictionary lookup."""
    text: str = Field(..., description="Text to look up")
    from_lang: str = Field(..., alias="from", description="Source language")
    to: str = Field(..., description="Target language")
    
    class Config:
        populate_by_name = True


class DictionaryLookupResponse(BaseModel):
    """Response model for dictionary lookup."""
    results: List[Dict[str, Any]]
    request_id: Optional[str] = None


class DictionaryExamplesRequest(BaseModel):
    """Request model for dictionary examples."""
    text: str = Field(..., description="Source text")
    translation: str = Field(..., description="Translation text")
    from_lang: str = Field(..., alias="from", description="Source language")
    to: str = Field(..., description="Target language")
    
    class Config:
        populate_by_name = True


class DictionaryExamplesResponse(BaseModel):
    """Response model for dictionary examples."""
    results: List[Dict[str, Any]]
    request_id: Optional[str] = None


class Language(BaseModel):
    """Language information."""
    name: str
    native_name: str = Field(..., alias="nativeName")
    dir: str
    
    class Config:
        populate_by_name = True


class LanguagesResponse(BaseModel):
    """Response model for supported languages."""
    translation: Dict[str, Language]
    transliteration: Optional[Dict[str, Any]] = None
    dictionary: Optional[Dict[str, Any]] = None


class ErrorResponse(BaseModel):
    """Error response model."""
    error: Dict[str, Any]
    request_id: Optional[str] = None


class HealthResponse(BaseModel):
    """Health check response."""
    status: str
    version: str
    timestamp: str


# Batch Translation Models

class BatchJobRequest(BaseModel):
    """Request model for starting a batch translation job."""
    source_container: str = Field(..., description="Source blob container name")
    target_container: str = Field(..., description="Target blob container name")
    target_language: str = Field(..., description="Target language code")
    source_language: Optional[str] = Field(default=None, description="Source language code (auto-detect if None)")
    prefix: Optional[str] = Field(default=None, description="Optional prefix to filter source files")
    dictionary: Optional[Dict[str, str]] = Field(default=None, description="Custom dictionary terms for translation (term: translation)")


class BatchJobResponse(BaseModel):
    """Response model for batch job creation."""
    job_id: str
    status: str
    total_files: int
    source_container: str
    target_container: str
    target_language: str
    created_at: str


class BatchJobStatusResponse(BaseModel):
    """Response model for batch job status."""
    job_id: str
    status: str
    queue_length: int


class TranslatedFileInfo(BaseModel):
    """Information about a translated file."""
    filename: str
    nmt_blob: str
    llm_blob: str
    size: int
    last_modified: Optional[str] = None


class TranslatedFilesResponse(BaseModel):
    """Response model for listing translated files."""
    files: List[TranslatedFileInfo]
    total_nmt: int
    total_llm: int
    matched: int


class FileTranslationContent(BaseModel):
    """Content of NMT and LLM translations for a file."""
    filename: str
    nmt_content: str
    llm_content: str
    nmt_blob: str
    llm_blob: str


class RatingRequest(BaseModel):
    """Request model for rating translations."""
    filename: str
    container: str
    nmt_blob: str
    llm_blob: str
    preferred: str = Field(..., description="Preferred translation: 'nmt' or 'llm'")
    comments: Optional[str] = Field(default=None, description="Optional comments")


class RatingResponse(BaseModel):
    """Response model for rating submission."""
    success: bool
    message: str
    rating_id: Optional[str] = None


class RatingStats(BaseModel):
    """Statistics for translation ratings."""
    total_ratings: int
    nmt_preferred: int
    llm_preferred: int
    nmt_percentage: float
    llm_percentage: float
