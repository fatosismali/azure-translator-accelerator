# LLM Translation with Azure Translator 2025-05-01-preview

## Overview

This accelerator now supports the **Azure AI Translator 2025-05-01-preview API** with Large Language Model (LLM) translation capabilities using GPT-4o and GPT-4o-mini.

## Features

### 🤖 LLM Translation Models
- **GPT-4o-mini**: Faster, more cost-effective LLM translation
- **GPT-4o**: Highest quality, best context understanding

### 🎯 Advanced Capabilities

1. **Tone Variants**
   - `formal`: Professional, business-appropriate language
   - `informal`: Casual, conversational style
   - `neutral`: Balanced, standard tone

2. **Gender-Specific Translation**
   - `male`: Male-oriented linguistic transformations
   - `female`: Female-oriented linguistic transformations
   - `neutral`: Gender-neutral language

3. **Adaptive Custom Translation**
   - Provide up to 5 reference translations
   - LLM learns from examples for consistent style
   - Few-shot learning for domain-specific translations

4. **Side-by-Side Comparison**
   - Compare NMT vs LLM translations
   - View pros/cons of each approach
   - Analyze character counts and cost estimates

## API Endpoints

### 1. LLM Translation

```bash
POST /api/v1/translate/llm
```

**Request Body:**
```json
{
  "text": "Hello, how are you?",
  "to": ["es"],
  "from": "en",
  "model": "gpt-4o-mini",
  "tone": "formal",
  "gender": "neutral",
  "reference_translations": [
    "Hola, ¿cómo está usted?",
    "Buenos días, ¿cómo se encuentra?"
  ]
}
```

**Response:**
```json
{
  "translations": [
    {
      "translations": [
        {
          "text": "Hola, ¿cómo está usted?",
          "to": "es"
        }
      ]
    }
  ],
  "request_id": "uuid-here"
}
```

### 2. NMT vs LLM Comparison

```bash
POST /api/v1/translate/compare
```

**Request Body:**
```json
{
  "text": "The meeting will take place tomorrow.",
  "to": "es",
  "from": "en",
  "llm_model": "gpt-4o-mini",
  "tone": "formal"
}
```

**Response:**
```json
{
  "request_id": "uuid",
  "source_text": "The meeting will take place tomorrow.",
  "source_language": "en",
  "target_language": "es",
  "nmt": {
    "translation": {...},
    "error": null,
    "model": "Neural Machine Translation",
    "api_version": "3.0"
  },
  "llm": {
    "translation": {...},
    "error": null,
    "model": "gpt-4o-mini",
    "api_version": "2025-05-01-preview",
    "tone": "formal",
    "gender": null
  }
}
```

## Prerequisites

### Azure AI Foundry Resource

⚠️ **Important**: LLM translation requires an **Azure AI Foundry** resource in addition to the Azure Translator resource.

#### Setup Steps:

1. **Create Azure AI Foundry Resource**
   ```bash
   az cognitiveservices account create \
     --name your-ai-foundry \
     --resource-group translator-dev-rg \
     --kind AIServices \
     --sku S0 \
     --location uksouth
   ```

2. **Get Endpoint and Key**
   ```bash
   # Get endpoint
   az cognitiveservices account show \
     --name your-ai-foundry \
     --resource-group translator-dev-rg \
     --query properties.endpoint -o tsv
   
   # Get key
   az cognitiveservices account keys list \
     --name your-ai-foundry \
     --resource-group translator-dev-rg \
     --query key1 -o tsv
   ```

3. **Update Environment Variables**
   Add to your `.env` file:
   ```env
   AZURE_AI_FOUNDRY_ENDPOINT=https://your-ai-foundry.cognitiveservices.azure.com/
   AZURE_AI_FOUNDRY_KEY=your-key-here
   ```

## Usage in UI

### Translation Comparison Tab

1. Open http://localhost:3000
2. Click the **"⚖️ NMT vs LLM"** tab
3. Enter text to translate
4. Select languages
5. Choose LLM model and optional tone/gender
6. Click **"⚖️ Compare Translations"**

### What You'll See

**Left Side (NMT)**:
- Fast, reliable translation
- Cost-effective
- Proven neural translation

**Right Side (LLM)**:
- Contextual understanding
- Tone-aware translation
- Gender-specific options
- Natural phrasing

## Limits and Pricing

### Service Limits

| Feature | NMT (3.0) | LLM (Preview) |
|---------|-----------|---------------|
| Max Array Elements | 1,000 | 50 |
| Max Element Size | 50,000 chars | 5,000 chars |
| Pricing Model | Per character | Per token |

### Cost Comparison

- **NMT**: ~$10 per 1M characters
- **LLM (GPT-4o-mini)**: ~$0.15 per 1M input tokens + $0.60 per 1M output tokens
- **LLM (GPT-4o)**: ~$5 per 1M input tokens + $15 per 1M output tokens

💡 **Tip**: Use NMT for high-volume, cost-sensitive workloads. Use LLM for quality-critical, context-sensitive translations.

## Use Cases

### Best for NMT
- ✅ High-volume translation
- ✅ Real-time translation
- ✅ Cost-sensitive applications
- ✅ General-purpose translation
- ✅ Long documents (up to 50K chars)

### Best for LLM
- ✅ Marketing content
- ✅ Customer-facing communications
- ✅ Tone-sensitive content
- ✅ Gender-specific content
- ✅ Domain-specific translation (with reference examples)
- ✅ Creative or nuanced text

## Examples

### Example 1: Formal Business Email

```bash
curl -X POST http://localhost:8000/api/v1/translate/compare \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Thank you for your interest in our product.",
    "to": "es",
    "from": "en",
    "llm_model": "gpt-4o-mini",
    "tone": "formal"
  }'
```

**NMT**: "Gracias por su interés en nuestro producto."
**LLM**: "Le agradecemos sinceramente su interés en nuestro producto." (more formal)

### Example 2: Casual Conversation

```bash
curl -X POST http://localhost:8000/api/v1/translate/llm \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Hey, what are you up to?",
    "to": ["es"],
    "from": "en",
    "model": "gpt-4o-mini",
    "tone": "informal"
  }'
```

**Result**: "Oye, ¿qué estás haciendo?" (casual tone preserved)

### Example 3: Gender-Specific Translation

```bash
curl -X POST http://localhost:8000/api/v1/translate/llm \
  -H "Content-Type: application/json" \
  -d '{
    "text": "I am a teacher",
    "to": ["es"],
    "from": "en",
    "model": "gpt-4o-mini",
    "gender": "female"
  }'
```

**Result**: "Soy una profesora" (feminine form)

## Troubleshooting

### Error: "No valid translation targets were supplied"

This usually means:
1. Azure AI Foundry resource is not configured
2. The preview API endpoint needs specific configuration
3. Check your `AZURE_AI_FOUNDRY_ENDPOINT` and `AZURE_AI_FOUNDRY_KEY` environment variables

### Error: 403 Forbidden

- Ensure your Azure AI Foundry resource is in the same region as your Translator resource
- Verify API keys are correct
- Check that the preview API is enabled in your subscription

### LLM Translation Returns Error

- The preview API is in preview and may have region restrictions
- Ensure you have the correct API version: `2025-05-01-preview`
- Verify your Azure subscription has access to Azure AI Foundry

## Architecture Updates

### Backend Changes

1. **New Service Method**: `translate_with_llm()` in `translator_service.py`
2. **New API Models**: `TranslateLLMRequest`, `CompareTranslationRequest`
3. **New Routes**: `/translate/llm`, `/translate/compare`
4. **Config Updates**: Added `azure_translator_api_version_preview`, Azure AI Foundry settings

### Frontend Changes

1. **New Component**: `TranslationComparison.tsx`
2. **Updated App**: Added "⚖️ NMT vs LLM" tab
3. **Side-by-Side UI**: Visual comparison with pros/cons

## References

- [Azure AI Translator 2025-05-01-preview Overview](https://learn.microsoft.com/en-us/azure/ai-services/translator/text-translation/preview/overview)
- [Azure OpenAI Pricing](https://azure.microsoft.com/pricing/details/cognitive-services/openai-service/)
- [Azure Translator Pricing](https://azure.microsoft.com/pricing/details/cognitive-services/translator/)

## Next Steps

1. **Set up Azure AI Foundry** to enable LLM translations
2. **Experiment with tones** to see how LLM adapts style
3. **Try reference translations** for domain-specific terminology
4. **Monitor costs** using Application Insights
5. **A/B test** NMT vs LLM for your use case

---

**Status**: ✅ Implemented | ⚠️ Requires Azure AI Foundry Setup


