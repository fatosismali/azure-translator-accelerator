# Dynamic Dictionary Feature

## Overview

The Dynamic Dictionary feature allows users to define custom translations for specific terms in batch translation jobs. This feature leverages Azure Translator's [dynamic dictionary capability](https://learn.microsoft.com/azure/ai-services/translator/text-translation/how-to/use-dynamic-dictionary) by automatically annotating source text with `<mstrans:dictionary>` tags before translation.

## Use Cases

- **Brand Names**: Preserve or translate brand names consistently (e.g., "wordomatic" → "Wordomatic")
- **Technical Terms**: Maintain specific technical vocabulary across translations
- **Product Names**: Keep product names unchanged in translations
- **Domain-Specific Terms**: Apply custom translations for industry-specific terminology

## How It Works

### Frontend (Batch Tab - Step 3)

Users can add dictionary entries with three inputs:

1. **Source Term**: The term to find in the source text (e.g., "wordomatic")
2. **Target Translation**: The desired translation (e.g., "Wordomatic")
3. **Translate Checkbox**: 
   - ✓ **Checked** (default): Translate the term to the specified translation
   - ⊘ **Unchecked**: Preserve the term as-is (auto-fills target with source term)

**Example UI Flow:**
```
Source Term: API
Target Translation: API
Translate: ⊘ (unchecked)
→ Result: "API" will remain "API" in all translations
```

```
Source Term: wordomatic
Target Translation: Wordomático
Translate: ✓ (checked)
→ Result: "wordomatic" will become "Wordomático" in Spanish translation
```

### Backend Processing

1. **API Reception**: The dictionary is sent as `{term: translation}` pairs
2. **Text Annotation**: Before translation, the batch service annotates text:
   ```python
   # Original text
   "The word wordomatic is a dictionary entry."
   
   # Annotated text (with dictionary: {"wordomatic": "Wordomático"})
   "The word <mstrans:dictionary translation=\"Wordomático\">wordomatic</mstrans:dictionary> is a dictionary entry."
   ```
3. **Translation**: Azure Translator processes the annotated text and applies custom translations
4. **Storage**: Both NMT and LLM translations use the dictionary annotations

### Technical Implementation

#### Frontend Components

**BatchTranslation.tsx**
- Added `DictionaryEntry` interface
- Added state management for dictionary entries
- Added UI for adding/removing dictionary terms
- Updated API call to include dictionary

**api.ts**
- Updated `startBatchJob()` to accept optional `dictionary` parameter

#### Backend Components

**models.py**
- Added `dictionary: Optional[Dict[str, str]]` field to `BatchJobRequest`

**routes.py**
- Updated `/batch/jobs` endpoint to pass dictionary to batch service

**batch_service.py**
- Added `annotate_text_with_dictionary()` method:
  - Sorts terms by length (longest first) to avoid partial matches
  - Uses regex word boundary matching (`\b`) for whole-word replacement
  - Case-insensitive matching
  - Escapes special regex characters in terms
- Updated `start_batch_job()` to apply annotations before translation

## Example Scenarios

### Scenario 1: Preserve Technical Terms

**Goal**: Keep "API" unchanged in French translation

**Dictionary Entry:**
- Source Term: `API`
- Target Translation: `API`
- Translate: ⊘ (unchecked)

**Source Text:**
```
The API provides access to translation services.
```

**Annotated Text:**
```
The <mstrans:dictionary translation="API">API</mstrans:dictionary> provides access to translation services.
```

**French Translation:**
```
L'API fournit un accès aux services de traduction.
```

### Scenario 2: Custom Brand Translation

**Goal**: Translate "Contoso" to "康托索" (Chinese)

**Dictionary Entry:**
- Source Term: `Contoso`
- Target Translation: `康托索`
- Translate: ✓ (checked)

**Source Text:**
```
Welcome to Contoso Corporation.
```

**Annotated Text:**
```
Welcome to <mstrans:dictionary translation="康托索">Contoso</mstrans:dictionary> Corporation.
```

**Chinese Translation:**
```
欢迎来到康托索公司。
```

### Scenario 3: Mixed Terms

**Dictionary Entries:**
1. `API` → `API` (preserve)
2. `Azure Translator` → `Azure Translator` (preserve)
3. `gpt-4o-mini` → `GPT-4o Mini` (custom capitalization)

**Source Text:**
```
The API uses Azure Translator with gpt-4o-mini model.
```

**Result:**
All three terms will be handled according to their dictionary definitions.

## Azure Translator Requirements

According to [Microsoft's documentation](https://learn.microsoft.com/azure/ai-services/translator/text-translation/how-to/use-dynamic-dictionary):

- **Language Requirement**: The source (`From`) and target (`To`) languages must include English and another supported language
- **Source Language**: You must include the `From` parameter (cannot use auto-detect with dictionary)
- **Best for**: Compound nouns like proper names and product names
- **HTML Mode**: Works with both plain text and HTML

## Limitations

1. **Case Sensitivity**: The annotation is case-insensitive, but preserves the original case in the annotated text
2. **Whole Word Matching**: Only complete words are matched (not partial matches)
3. **Regex Special Characters**: Special regex characters in terms are properly escaped
4. **Order Matters**: Longer terms are processed first to avoid partial replacements

## API Reference

### Frontend API Call

```typescript
translatorAPI.startBatchJob(
  sourceContainer: string,
  targetContainer: string,
  targetLanguage: string,
  sourceLanguage?: string,
  dictionary?: Record<string, string>
)
```

### Backend API Endpoint

**POST** `/api/v1/batch/jobs`

```json
{
  "source_container": "source-texts",
  "target_container": "translations",
  "target_language": "es",
  "source_language": "en",
  "dictionary": {
    "API": "API",
    "wordomatic": "Wordomático",
    "Contoso": "Contoso Corporation"
  }
}
```

## Testing the Feature

1. Navigate to the **Batch** tab
2. Select source and target containers
3. Select languages (ensure source language is specified for dictionary to work)
4. Add dictionary entries:
   - Add terms you want to preserve (uncheck "Translate")
   - Add terms with custom translations (check "Translate" and specify translation)
5. Start the batch job
6. Check the translated files in the Review tab to verify custom terms were applied

## Performance Considerations

- Dictionary annotation happens in-memory before API calls
- Regex matching is optimized by sorting terms by length
- No impact on translation speed (Azure Translator processes tags efficiently)
- Suitable for dictionaries with hundreds of terms

## Future Enhancements

- [ ] Import/export dictionary as CSV or JSON
- [ ] Save dictionary presets for reuse
- [ ] Dictionary term validation (check if term exists in source files)
- [ ] Support for phrase-level translations (multi-word terms)
- [ ] Dictionary statistics (how many times each term was found)
- [ ] Support for context-specific translations

## References

- [Azure Translator Dynamic Dictionary Documentation](https://learn.microsoft.com/azure/ai-services/translator/text-translation/how-to/use-dynamic-dictionary)
- [Azure Translator Text Translation API](https://learn.microsoft.com/azure/ai-services/translator/reference/v3-0-translate)

