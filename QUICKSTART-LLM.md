# 🚀 Quick Start: LLM Translation Comparison

## Access the Application

- **Frontend**: http://localhost:3000
- **API Docs**: http://localhost:8000/docs
- **Backend**: http://localhost:8000

## Try the New Features

### 1. Side-by-Side Comparison (Works Now!)

1. Open http://localhost:3000
2. Click the **"⚖️ NMT vs LLM"** tab
3. Enter text: `"The meeting will take place tomorrow at 3 PM."`
4. Select languages: English → Spanish
5. Choose LLM model: `gpt-4o-mini`
6. Click **"⚖️ Compare Translations"**

**You'll see**:
- ✅ **NMT** (left): Traditional translation - works immediately
- ⚠️ **LLM** (right): Shows error (requires Azure AI Foundry setup)

### 2. Dictionary Lookup (Already Working!)

1. Click the **"📖 Dictionary"** tab
2. Enter a word: `"hello"`
3. Select: English → Spanish
4. Click **"🔍 Look Up"**
5. See alternative translations with confidence scores
6. Click **"📝 Examples"** for usage examples

## Test via API

### NMT Translation (Working)
```bash
curl -X POST http://localhost:8000/api/v1/translate \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Hello, world!",
    "to": ["es"],
    "from": "en"
  }'
```

### Comparison (NMT works, LLM needs setup)
```bash
curl -X POST http://localhost:8000/api/v1/translate/compare \
  -H "Content-Type: application/json" \
  -d '{
    "text": "The meeting will take place tomorrow.",
    "to": "es",
    "from": "en",
    "llm_model": "gpt-4o-mini",
    "tone": "formal"
  }' | jq '.'
```

### Dictionary Lookup (Working)
```bash
curl -X POST http://localhost:8000/api/v1/dictionary/lookup \
  -H "Content-Type: application/json" \
  -d '{
    "text": "computer",
    "from": "en",
    "to": "es"
  }' | jq '.'
```

## Enable Full LLM Translation

To enable the LLM side of the comparison:

### Option 1: Quick Test (Azure AI Foundry)

```bash
# 1. Create Azure AI Foundry resource
az cognitiveservices account create \
  --name translator-ai-foundry \
  --resource-group translator-dev-rg \
  --kind AIServices \
  --sku S0 \
  --location uksouth

# 2. Get credentials
FOUNDRY_ENDPOINT=$(az cognitiveservices account show \
  --name translator-ai-foundry \
  --resource-group translator-dev-rg \
  --query properties.endpoint -o tsv)

FOUNDRY_KEY=$(az cognitiveservices account keys list \
  --name translator-ai-foundry \
  --resource-group translator-dev-rg \
  --query key1 -o tsv)

# 3. Add to .env
echo "AZURE_AI_FOUNDRY_ENDPOINT=$FOUNDRY_ENDPOINT" >> .env
echo "AZURE_AI_FOUNDRY_KEY=$FOUNDRY_KEY" >> .env

# 4. Restart containers
docker compose down && docker compose up -d
```

### Option 2: Use Existing Preview (If Available)

The 2025-05-01-preview API is in preview. You can:
1. Check Azure portal for preview access
2. Register for preview features
3. Contact Azure support for early access

## Files Changed

### Backend
- ✅ `src/backend/app/config.py` - Added preview API config
- ✅ `src/backend/app/services/translator_service.py` - Added LLM method
- ✅ `src/backend/app/api/models.py` - Added LLM request models
- ✅ `src/backend/app/api/routes.py` - Added LLM endpoints

### Frontend
- ✅ `src/frontend/src/components/TranslationComparison.tsx` - New component
- ✅ `src/frontend/src/App.tsx` - Added comparison tab

### Documentation
- ✅ `docs/llm-translation.md` - Complete LLM guide
- ✅ `README.md` - Updated features list
- ✅ `QUICKSTART-LLM.md` - This file!

## What's Working Now

✅ **Translation Tab**
- Standard NMT translation
- Multi-language support
- Fast and reliable

✅ **Dictionary Tab**
- Alternative translations
- Usage examples with context
- Back-translations
- Confidence scores

✅ **Comparison Tab (Partial)**
- NMT side working perfectly
- LLM side gracefully shows error
- Full UI/UX ready
- Side-by-side layout
- Cost analysis
- Pros/cons display

## Example Comparison Output

```json
{
  "request_id": "uuid",
  "source_text": "The meeting will take place tomorrow at 3 PM.",
  "target_language": "es",
  "nmt": {
    "translation": {
      "translations": [{
        "text": "La reunión tendrá lugar mañana a las 3 PM.",
        "to": "es"
      }]
    },
    "model": "Neural Machine Translation",
    "api_version": "3.0"
  },
  "llm": {
    "error": "Requires Azure AI Foundry (setup pending)",
    "model": "gpt-4o-mini",
    "api_version": "2025-05-01-preview"
  }
}
```

## Next Steps

1. ✅ **Try the comparison UI** - See NMT working, understand LLM capability
2. ✅ **Test dictionary feature** - Fully working with examples
3. 📖 **Read docs/llm-translation.md** - Detailed guide
4. 🔧 **Set up Azure AI Foundry** - Enable full LLM features (optional)
5. 🚀 **Deploy to Azure** - Use deployment scripts

## Key Differences: NMT vs LLM

| Feature | NMT | LLM |
|---------|-----|-----|
| Speed | ⚡ Very fast (~200ms) | 🐢 Slower (~1-3s) |
| Cost | 💰 $10/1M chars | 💰💰 $0.15-5/1M tokens |
| Quality | ⭐⭐⭐⭐ Good | ⭐⭐⭐⭐⭐ Excellent |
| Tone Control | ❌ No | ✅ Yes |
| Gender-Specific | ❌ No | ✅ Yes |
| Context Understanding | ⭐⭐⭐ Good | ⭐⭐⭐⭐⭐ Excellent |
| Use Case | High-volume | Quality-critical |

## Support

- 📚 **Documentation**: `docs/llm-translation.md`
- 🐛 **Issues**: Check `docs/troubleshooting.md`
- 📖 **Azure Docs**: https://learn.microsoft.com/en-us/azure/ai-services/translator/text-translation/preview/overview

---

**Ready to go!** 🎉 Open http://localhost:3000 and click the "⚖️ NMT vs LLM" tab.

