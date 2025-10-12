"""
Azure Translator Service Integration.
Handles all API calls to Azure AI Translator with retry logic and error handling.
"""

import logging
from typing import Dict, List, Optional, Any, Union
import httpx
import backoff
from app.config import Settings

logger = logging.getLogger(__name__)


class TranslatorServiceException(Exception):
    """Base exception for translator service errors."""
    pass


class RateLimitException(TranslatorServiceException):
    """Exception for rate limit errors."""
    pass


class TranslatorService:
    """Service class for Azure Translator API integration."""
    
    def __init__(self, settings: Settings):
        """
        Initialize translator service.
        
        Args:
            settings: Application settings
        """
        self.settings = settings
        # NMT endpoints
        self.base_url = settings.translator_base_url
        self.api_version = settings.azure_translator_api_version
        self.key = settings.azure_translator_key
        self.region = settings.azure_translator_region
        # LLM endpoints (AI Foundry)
        self.preview_api_version = settings.azure_translator_api_version_preview
        self.ai_foundry_endpoint = settings.azure_ai_foundry_endpoint
        self.ai_foundry_key = settings.azure_ai_foundry_key
        self.gpt4o_mini_deployment = settings.gpt4o_mini_deployment_name
        
        # HTTP client with timeout
        self.client = httpx.AsyncClient(
            timeout=httpx.Timeout(30.0),
            follow_redirects=True,
        )
    
    def _get_headers(self) -> Dict[str, str]:
        """Get standard headers for Translator API requests."""
        return {
            "Ocp-Apim-Subscription-Key": self.key,
            "Ocp-Apim-Subscription-Region": self.region,
            "Content-Type": "application/json",
        }
    
    @backoff.on_exception(
        backoff.expo,
        (httpx.RequestError, RateLimitException),
        max_tries=3,
        max_time=30,
    )
    async def _make_request(
        self,
        method: str,
        endpoint: str,
        params: Optional[Dict[str, Any]] = None,
        json_data: Optional[Any] = None,
    ) -> Any:
        """
        Make HTTP request to Translator API with retry logic.
        
        Args:
            method: HTTP method (GET, POST)
            endpoint: API endpoint
            params: Query parameters
            json_data: JSON request body
            
        Returns:
            Response JSON data
            
        Raises:
            RateLimitException: When rate limited (429)
            TranslatorServiceException: For other errors
        """
        url = f"{self.base_url}/{endpoint}"
        headers = self._get_headers()
        
        try:
            response = await self.client.request(
                method=method,
                url=url,
                params=params,
                json=json_data,
                headers=headers,
            )
            
            # Handle rate limiting with exponential backoff
            if response.status_code == 429:
                logger.warning("Rate limit hit, retrying with backoff...")
                raise RateLimitException("Rate limit exceeded")
            
            # Handle other errors
            if response.status_code >= 400:
                error_detail = response.text
                logger.error(f"Translator API error ({response.status_code}): {error_detail}")
                raise TranslatorServiceException(
                    f"Translator API error: {response.status_code} - {error_detail}"
                )
            
            return response.json()
        
        except httpx.RequestError as e:
            logger.error(f"Request error: {str(e)}")
            raise TranslatorServiceException(f"Request failed: {str(e)}")
    
    @backoff.on_exception(
        backoff.expo,
        (httpx.RequestError, RateLimitException),
        max_tries=3,
        max_time=30,
    )
    async def _make_llm_request(
        self,
        params: Optional[Dict[str, Any]] = None,
        json_data: Optional[Any] = None,
    ) -> Any:
        """
        Make HTTP request to Translator API with AI Foundry credentials for LLM translation.
        
        Uses Translator endpoint as gateway but authenticates with AI Foundry region and key
        to access AI Foundry deployments (gpt-4o-mini).
        
        Args:
            params: Query parameters (including api-version)
            json_data: JSON request body with targets array
            
        Returns:
            Response JSON data
            
        Raises:
            RateLimitException: When rate limited (429)
            TranslatorServiceException: For other errors
        """
        # Use Translator API endpoint as gateway
        url = f"{self.base_url}/translate"
        
        # Get AI Foundry region from endpoint
        # Extract region from: https://translator-dev-foundry-zkavo6qequjns.cognitiveservices.azure.com/
        # The region for AIServices is the deployment location (swedencentral)
        ai_foundry_region = "swedencentral"  # AI Foundry is deployed in Sweden Central
        
        # Use AI Foundry credentials in headers
        headers = {
            "Ocp-Apim-Subscription-Key": self.ai_foundry_key,
            "Ocp-Apim-Subscription-Region": ai_foundry_region,
            "Content-Type": "application/json",
        }
        
        logger.info(f"[LLM] Making request to: {url}")
        logger.info(f"[LLM] Using AI Foundry credentials - Region: {ai_foundry_region}")
        logger.info(f"[LLM] Params: {params}")
        
        try:
            response = await self.client.request(
                method="POST",
                url=url,
                params=params,
                json=json_data,
                headers=headers,
            )
            
            # Handle rate limiting
            if response.status_code == 429:
                logger.warning("Rate limit hit, retrying with backoff...")
                raise RateLimitException("Rate limit exceeded")
            
            # Handle errors
            if response.status_code >= 400:
                error_detail = response.text
                logger.error(f"LLM Translation API error ({response.status_code}): {error_detail}")
                raise TranslatorServiceException(
                    f"LLM Translation API error: {response.status_code} - {error_detail}"
                )
            
            return response.json()
        
        except httpx.RequestError as e:
            logger.error(f"LLM request error: {str(e)}")
            raise TranslatorServiceException(f"LLM request failed: {str(e)}")
    
    async def translate(
        self,
        text: Union[str, List[str]],
        to: List[str],
        from_lang: Optional[str] = None,
        text_type: Optional[str] = None,
        category: Optional[str] = None,
        profanity_action: Optional[str] = None,
        profanity_marker: Optional[str] = None,
        include_alignment: Optional[bool] = False,
        include_sentence_length: Optional[bool] = False,
        suggested_from: Optional[str] = None,
        from_script: Optional[str] = None,
        to_script: Optional[str] = None,
        allow_fallback: Optional[bool] = True,
    ) -> List[Dict[str, Any]]:
        """
        Translate text to one or more target languages.
        
        API Reference: https://learn.microsoft.com/azure/ai-services/translator/reference/v3-0-translate
        
        Args:
            text: Text or list of texts to translate
            to: List of target language codes
            from_lang: Source language code (auto-detect if None)
            text_type: Type of text (plain or html)
            category: Translation category
            profanity_action: How to handle profanity (NoAction, Marked, Deleted)
            profanity_marker: Profanity marker (Asterisk or Tag)
            include_alignment: Include word alignment
            include_sentence_length: Include sentence boundaries
            suggested_from: Suggested source language
            from_script: Source script for transliteration
            to_script: Target script for transliteration
            allow_fallback: Allow fallback to general system
            
        Returns:
            List of translation results
        """
        # Build query parameters
        params = {
            "api-version": self.api_version,
            "to": to,
        }
        
        if from_lang:
            params["from"] = from_lang
        if text_type:
            params["textType"] = text_type
        if category:
            params["category"] = category
        if profanity_action:
            params["profanityAction"] = profanity_action
        if profanity_marker:
            params["profanityMarker"] = profanity_marker
        if include_alignment:
            params["includeAlignment"] = "true"
        if include_sentence_length:
            params["includeSentenceLength"] = "true"
        if suggested_from:
            params["suggestedFrom"] = suggested_from
        if from_script:
            params["fromScript"] = from_script
        if to_script:
            params["toScript"] = to_script
        if allow_fallback is False:
            params["allowFallback"] = "false"
        
        # Prepare request body
        if isinstance(text, str):
            body = [{"Text": text}]
        else:
            body = [{"Text": t} for t in text]
        
        logger.info(f"Translating {len(body)} text(s) to {len(to)} language(s)")
        
        result = await self._make_request(
            method="POST",
            endpoint="translate",
            params=params,
            json_data=body,
        )
        
        # Log raw response for debugging
        logger.info(f"[NMT RAW RESPONSE] {result}")
        
        return result
    
    async def translate_with_llm(
        self,
        text: Union[str, List[str]],
        to: List[str],
        from_lang: Optional[str] = None,
        model: str = "gpt-4o-mini",
        tone: Optional[str] = None,
        gender: Optional[str] = None,
        reference_translations: Optional[List[str]] = None,
        text_type: Optional[str] = None,
        profanity_action: Optional[str] = None,
    ) -> List[Dict[str, Any]]:
        """
        Translate text using LLM models (GPT-4o-mini or GPT-4o) with 2025-05-01-preview API.
        
        API Reference: https://learn.microsoft.com/en-us/azure/ai-services/translator/text-translation/how-to/migrate-to-preview
        
        Note: Using LLM models requires an Azure AI Foundry resource.
        
        Args:
            text: Text or list of texts to translate (max 50 items, 5000 chars each)
            to: List of target language codes
            from_lang: Source language code (auto-detect if None)
            model: LLM model to use ("gpt-4o-mini" or "gpt-4o")
            tone: Tone variant (formal, informal, neutral)
            gender: Gender-specific translation (male, female, neutral)
            reference_translations: Up to 5 reference translations for adaptive custom translation
            text_type: Type of text (plain or html)
            profanity_action: How to handle profanity (NoAction, Marked, Deleted)
            
        Returns:
            List of translation results
        """
        # Build query parameters for preview API
        # Note: model is specified in targets.deploymentName, not as query param
        params = {
            "api-version": self.preview_api_version,
        }
        
        if from_lang:
            params["from"] = from_lang
        if text_type:
            params["textType"] = text_type
        if profanity_action:
            params["profanityAction"] = profanity_action
        
        # Prepare request body with 2025-05-01-preview structure
        # Key change: use "targets" array instead of "to" query parameter
        if isinstance(text, str):
            body = [{"text": text}]
        else:
            body = [{"text": t} for t in text]
        
        # Build targets array with language and optional parameters
        # CRITICAL: deploymentName in targets tells Azure to use LLM instead of NMT
        # When using AI Foundry unified endpoint, deploymentName is just the model deployment name
        # (e.g., "gpt-4o-mini") since the deployment exists within the same AI Foundry resource
        deployment_name = "gpt-4o-mini" if model == "gpt-4o-mini" else "gpt-4o"
        
        for item in body:
            targets = []
            for lang in to:
                target = {
                    "language": lang,
                    "deploymentName": deployment_name  # Reference to AI Foundry deployment
                }
                if tone:
                    target["tone"] = tone  # formal, informal, neutral
                if gender:
                    target["gender"] = gender  # male, female, neutral
                targets.append(target)
            item["targets"] = targets
            
            # Add reference translations for adaptive custom translation (max 5)
            if reference_translations:
                item["referenceTranslations"] = reference_translations[:5]
        
        logger.info(f"Translating {len(body)} text(s) to {len(to)} language(s) using LLM model: {model}")
        logger.info(f"[LLM REQUEST] Deployment name: {deployment_name}")
        logger.info(f"[LLM REQUEST] Request body: {body}")
        logger.info(f"[LLM REQUEST] Using AI Foundry endpoint with AI Foundry key")
        
        # Use AI Foundry endpoint with AI Foundry's own key
        # AI Foundry (AIServices) should have access to its own deployments
        if not self.ai_foundry_endpoint or not self.ai_foundry_key:
            raise TranslatorServiceException(
                "AI Foundry endpoint and key required for LLM translation. "
                "Please set AZURE_AI_FOUNDRY_ENDPOINT and AZURE_AI_FOUNDRY_KEY."
            )
        
        result = await self._make_llm_request(
            params=params,
            json_data=body,
        )
        
        # Log raw response for debugging
        logger.info(f"[LLM RAW RESPONSE] {result}")
        
        # Normalize 2025-05-01-preview response to match v3.0 structure
        # Preview API returns: {language: "es", text: "..."} 
        # v3.0 API returns: {to: "es", text: "..."}
        for item in result:
            if "translations" in item:
                for translation in item["translations"]:
                    if "language" in translation and "to" not in translation:
                        translation["to"] = translation.pop("language")
                    # Preserve LLM metadata if present
                    if "modelVersion" in item:
                        translation["modelVersion"] = item["modelVersion"]
                    if "modelFamily" in item:
                        translation["modelFamily"] = item["modelFamily"]
        
        return result
    
    async def detect(self, text: Union[str, List[str]]) -> List[Dict[str, Any]]:
        """
        Detect the language of input text.
        
        API Reference: https://learn.microsoft.com/azure/ai-services/translator/reference/v3-0-detect
        
        Args:
            text: Text or list of texts
            
        Returns:
            List of detection results
        """
        params = {"api-version": self.api_version}
        
        if isinstance(text, str):
            body = [{"Text": text}]
        else:
            body = [{"Text": t} for t in text]
        
        logger.info(f"Detecting language for {len(body)} text(s)")
        
        result = await self._make_request(
            method="POST",
            endpoint="detect",
            params=params,
            json_data=body,
        )
        
        return result
    
    async def transliterate(
        self,
        text: Union[str, List[str]],
        language: str,
        from_script: str,
        to_script: str,
    ) -> List[Dict[str, Any]]:
        """
        Convert text from one script to another.
        
        API Reference: https://learn.microsoft.com/azure/ai-services/translator/reference/v3-0-transliterate
        
        Args:
            text: Text or list of texts
            language: Language code
            from_script: Source script (e.g., "Arab", "Cyrl", "Latn")
            to_script: Target script
            
        Returns:
            List of transliteration results
        """
        params = {
            "api-version": self.api_version,
            "language": language,
            "fromScript": from_script,
            "toScript": to_script,
        }
        
        if isinstance(text, str):
            body = [{"Text": text}]
        else:
            body = [{"Text": t} for t in text]
        
        logger.info(f"Transliterating {len(body)} text(s) from {from_script} to {to_script}")
        
        result = await self._make_request(
            method="POST",
            endpoint="transliterate",
            params=params,
            json_data=body,
        )
        
        return result
    
    async def dictionary_lookup(
        self,
        text: str,
        from_lang: str,
        to: str,
    ) -> List[Dict[str, Any]]:
        """
        Look up alternative translations for a word/phrase.
        
        API Reference: https://learn.microsoft.com/azure/ai-services/translator/reference/v3-0-dictionary-lookup
        
        Args:
            text: Text to look up
            from_lang: Source language
            to: Target language
            
        Returns:
            List of dictionary entries
        """
        params = {
            "api-version": self.api_version,
            "from": from_lang,
            "to": to,
        }
        
        body = [{"Text": text}]
        
        logger.info(f"Dictionary lookup: {from_lang} -> {to}")
        
        result = await self._make_request(
            method="POST",
            endpoint="dictionary/lookup",
            params=params,
            json_data=body,
        )
        
        return result
    
    async def dictionary_examples(
        self,
        text: str,
        translation: str,
        from_lang: str,
        to: str,
    ) -> List[Dict[str, Any]]:
        """
        Get usage examples for a translation.
        
        API Reference: https://learn.microsoft.com/azure/ai-services/translator/reference/v3-0-dictionary-examples
        
        Args:
            text: Source text
            translation: Translation text
            from_lang: Source language
            to: Target language
            
        Returns:
            List of usage examples
        """
        params = {
            "api-version": self.api_version,
            "from": from_lang,
            "to": to,
        }
        
        body = [{"Text": text, "Translation": translation}]
        
        logger.info(f"Dictionary examples: {from_lang} -> {to}")
        
        result = await self._make_request(
            method="POST",
            endpoint="dictionary/examples",
            params=params,
            json_data=body,
        )
        
        return result
    
    async def dictionary_lookup_llm(
        self,
        text: str,
        from_lang: str,
        to: str,
    ) -> Dict[str, Any]:
        """
        LLM-powered dictionary lookup using GPT-4o-mini.
        
        Since 2025-05-01-preview removed dictionary endpoints, we use LLM translation
        with context to provide alternative translations, definitions, and examples.
        
        Args:
            text: Text to look up
            from_lang: Source language
            to: Target language
            
        Returns:
            Dictionary-like results with alternatives and context
        """
        # Use LLM to generate comprehensive translation alternatives
        # We'll make multiple requests to get different tones/contexts
        
        logger.info(f"LLM Dictionary lookup: {from_lang} -> {to} for '{text}'")
        
        # Get translations with different tones to simulate alternatives
        alternatives = []
        tones = ["formal", "informal", "neutral"]
        
        for tone in tones:
            try:
                result = await self.translate_with_llm(
                    text=text,
                    to=[to],
                    from_lang=from_lang,
                    model="gpt-4o-mini",
                    tone=tone,
                )
                
                if result and len(result) > 0 and "translations" in result[0]:
                    translation = result[0]["translations"][0]["text"]
                    alternatives.append({
                        "displayTarget": translation,
                        "prefixWord": "",
                        "posTag": tone.capitalize(),  # Use tone as part-of-speech tag
                        "confidence": 0.9,
                        "backTranslations": []
                    })
            except Exception as e:
                logger.warning(f"Failed to get {tone} translation: {str(e)}")
                continue
        
        # Return in dictionary lookup format
        return {
            "normalizedSource": text.lower(),
            "displaySource": text,
            "translations": alternatives[:5]  # Limit to top 5
        }
    
    async def get_languages(self, scope: str = "translation") -> Dict[str, Any]:
        """
        Get supported languages for translation, transliteration, or dictionary.
        
        API Reference: https://learn.microsoft.com/azure/ai-services/translator/reference/v3-0-languages
        
        Args:
            scope: Scope filter (translation, transliteration, dictionary)
            
        Returns:
            Dictionary of supported languages
        """
        params = {"api-version": self.api_version}
        
        if scope:
            params["scope"] = scope
        
        logger.info(f"Getting supported languages for scope: {scope}")
        
        result = await self._make_request(
            method="GET",
            endpoint="languages",
            params=params,
        )
        
        return result
    
    async def close(self):
        """Close HTTP client."""
        await self.client.aclose()

