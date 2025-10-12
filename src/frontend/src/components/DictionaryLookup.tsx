import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useMutation } from '@tanstack/react-query'
import translatorAPI from '../services/api'
import { trackEvent } from '../services/telemetry'

interface DictionaryLookupProps {
  initialText?: string
  initialFromLang?: string
  initialToLang?: string
}

export default function DictionaryLookup({
  initialText = '',
  initialFromLang = 'en',
  initialToLang = 'es',
}: DictionaryLookupProps) {
  const { t } = useTranslation()
  const [word, setWord] = useState(initialText)
  const [fromLang, setFromLang] = useState(initialFromLang)
  const [toLang, setToLang] = useState(initialToLang)
  const [lookupResults, setLookupResults] = useState<any>(null)
  const [selectedTranslation, setSelectedTranslation] = useState<{
    text: string
    translation: string
  } | null>(null)
  const [examples, setExamples] = useState<any>(null)
  const [compareMode, setCompareMode] = useState(false)
  const [comparisonResults, setComparisonResults] = useState<any>(null)

  // Dictionary lookup mutation
  const lookupMutation = useMutation({
    mutationFn: async () => {
      return translatorAPI.dictionaryLookup(word, fromLang, toLang)
    },
    onSuccess: (data) => {
      setLookupResults(data)
      setExamples(null)
      setSelectedTranslation(null)
      trackEvent('Dictionary_Lookup_Success', {
        word,
        fromLang,
        toLang,
      })
    },
    onError: (error: any) => {
      console.error('Dictionary lookup error:', error)
    },
  })

  // Dictionary comparison mutation
  const compareMutation = useMutation({
    mutationFn: async () => {
      return translatorAPI.compareDictionary(word, fromLang, toLang)
    },
    onSuccess: (data) => {
      setComparisonResults(data)
      trackEvent('Dictionary_Compare_Success', {
        word,
        fromLang,
        toLang,
      })
    },
    onError: (error: any) => {
      console.error('Dictionary comparison error:', error)
    },
  })

  // Dictionary examples mutation
  const examplesMutation = useMutation({
    mutationFn: async (params: { text: string; translation: string }) => {
      return translatorAPI.dictionaryExamples(params.text, params.translation, fromLang, toLang)
    },
    onSuccess: (data) => {
      setExamples(data)
      trackEvent('Dictionary_Examples_Success', {
        word: selectedTranslation?.text,
        translation: selectedTranslation?.translation,
      })
    },
  })

  const handleLookup = (e: React.FormEvent) => {
    e.preventDefault()
    if (word.trim()) {
      if (compareMode) {
        compareMutation.mutate()
      } else {
        lookupMutation.mutate()
      }
    }
  }

  const handleGetExamples = (sourceText: string, targetText: string) => {
    setSelectedTranslation({ text: sourceText, translation: targetText })
    examplesMutation.mutate({ text: sourceText, translation: targetText })
  }

  return (
    <div className="dictionary-lookup">
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1rem' }}>
        <div>
          <h2 style={{ marginBottom: '0.5rem', color: 'var(--azure-blue)' }}>
            📖 Dictionary Lookup
          </h2>
          <p style={{ color: 'var(--gray-700)' }}>
            Get alternative translations and usage examples for words and phrases
          </p>
        </div>
        <button
          onClick={() => {
            setCompareMode(!compareMode)
            setLookupResults(null)
            setComparisonResults(null)
            setExamples(null)
          }}
          style={{
            padding: '0.75rem 1.5rem',
            background: compareMode ? 'var(--azure-blue)' : 'var(--gray-200)',
            color: compareMode ? 'white' : 'var(--gray-700)',
            border: 'none',
            borderRadius: 'var(--border-radius)',
            cursor: 'pointer',
            fontWeight: 600,
            transition: 'all 0.2s',
          }}
        >
          {compareMode ? '⚖️ Compare Mode ON' : '🔄 Regular Mode'}
        </button>
      </div>

      <form onSubmit={handleLookup} style={{ marginBottom: '2rem' }}>
        <div className="form-group">
          <label htmlFor="dictionary-word">Word or Phrase</label>
          <input
            id="dictionary-word"
            type="text"
            value={word}
            onChange={(e) => setWord(e.target.value)}
            placeholder="Enter a word (e.g., 'hello', 'computer', 'thank you')"
            style={{
              width: '100%',
              padding: '0.75rem',
              border: '1px solid var(--gray-300)',
              borderRadius: 'var(--border-radius)',
              fontSize: '1rem',
            }}
          />
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
          <div className="form-group">
            <label htmlFor="dict-from">From</label>
            <select
              id="dict-from"
              value={fromLang}
              onChange={(e) => setFromLang(e.target.value)}
            >
              <option value="en">English</option>
              <option value="es">Spanish</option>
              <option value="fr">French</option>
              <option value="de">German</option>
              <option value="it">Italian</option>
              <option value="pt">Portuguese</option>
            </select>
          </div>

          <div className="form-group">
            <label htmlFor="dict-to">To</label>
            <select id="dict-to" value={toLang} onChange={(e) => setToLang(e.target.value)}>
              <option value="es">Spanish</option>
              <option value="en">English</option>
              <option value="fr">French</option>
              <option value="de">German</option>
              <option value="it">Italian</option>
              <option value="pt">Portuguese</option>
            </select>
          </div>
        </div>

        <button
          type="submit"
          className="btn-primary"
          disabled={lookupMutation.isPending || compareMutation.isPending || !word.trim()}
          style={{ marginTop: '1rem' }}
        >
          {lookupMutation.isPending || compareMutation.isPending
            ? 'Loading...'
            : compareMode
            ? '⚖️ Compare Dictionary'
            : '🔍 Look Up'}
        </button>
      </form>

      {/* Comparison Results (NMT vs LLM) */}
      {compareMode && comparisonResults && (
        <div style={{ marginBottom: '2rem' }}>
          <h3 style={{ marginBottom: '1rem', textAlign: 'center', color: 'var(--azure-blue)' }}>
            NMT vs LLM Dictionary Comparison
          </h3>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1.5rem' }}>
            {/* NMT Results */}
            <div
              style={{
                background: 'white',
                border: '2px solid var(--gray-300)',
                borderRadius: 'var(--border-radius)',
                padding: '1.5rem',
              }}
            >
              <div style={{ marginBottom: '1rem' }}>
                <h4 style={{ color: 'var(--gray-800)', marginBottom: '0.5rem' }}>
                  🔤 NMT Dictionary
                </h4>
                <div style={{ fontSize: '0.875rem', color: 'var(--gray-700)' }}>
                  {comparisonResults.nmt.method} (API v{comparisonResults.nmt.api_version})
                </div>
              </div>

              {comparisonResults.nmt.error ? (
                <div style={{ padding: '1rem', background: '#fee', color: '#c00', borderRadius: '4px' }}>
                  ❌ {comparisonResults.nmt.error}
                </div>
              ) : comparisonResults.nmt.result && comparisonResults.nmt.result.length > 0 ? (
                <div>
                  {comparisonResults.nmt.result.map((result: any, idx: number) => (
                    <div key={idx} style={{ marginBottom: '1rem' }}>
                      <div style={{ fontWeight: 600, marginBottom: '0.5rem' }}>
                        {result.displaySource}
                      </div>
                      {result.translations?.slice(0, 3).map((trans: any, transIdx: number) => (
                        <div
                          key={transIdx}
                          style={{
                            background: 'var(--gray-100)',
                            padding: '0.75rem',
                            borderRadius: '4px',
                            marginBottom: '0.5rem',
                          }}
                        >
                          <div style={{ fontWeight: 500 }}>{trans.displayTarget}</div>
                          <div style={{ fontSize: '0.875rem', color: 'var(--gray-700)' }}>
                            {trans.posTag} • {(trans.confidence * 100).toFixed(0)}% confidence
                          </div>
                        </div>
                      ))}
                    </div>
                  ))}
                </div>
              ) : (
                <div style={{ padding: '1rem', background: 'var(--gray-100)', borderRadius: '4px' }}>
                  No results found
                </div>
              )}
            </div>

            {/* LLM Results */}
            <div
              style={{
                background: 'white',
                border: '2px solid var(--azure-blue)',
                borderRadius: 'var(--border-radius)',
                padding: '1.5rem',
              }}
            >
              <div style={{ marginBottom: '1rem' }}>
                <h4 style={{ color: 'var(--azure-blue)', marginBottom: '0.5rem' }}>
                  🤖 LLM Dictionary
                </h4>
                <div style={{ fontSize: '0.875rem', color: 'var(--gray-700)' }}>
                  {comparisonResults.llm.method}
                </div>
                <div style={{ fontSize: '0.75rem', color: 'var(--gray-600)', marginTop: '0.25rem' }}>
                  {comparisonResults.llm.note}
                </div>
              </div>

              {comparisonResults.llm.error ? (
                <div style={{ padding: '1rem', background: '#fee', color: '#c00', borderRadius: '4px' }}>
                  ❌ {comparisonResults.llm.error}
                </div>
              ) : comparisonResults.llm.result ? (
                <div>
                  <div style={{ fontWeight: 600, marginBottom: '0.5rem' }}>
                    {comparisonResults.llm.result.displaySource}
                  </div>
                  {comparisonResults.llm.result.translations?.map((trans: any, transIdx: number) => (
                    <div
                      key={transIdx}
                      style={{
                        background: 'rgba(0, 120, 215, 0.05)',
                        padding: '0.75rem',
                        borderRadius: '4px',
                        marginBottom: '0.5rem',
                        border: '1px solid rgba(0, 120, 215, 0.2)',
                      }}
                    >
                      <div style={{ fontWeight: 500 }}>{trans.displayTarget}</div>
                      <div style={{ fontSize: '0.875rem', color: 'var(--gray-700)' }}>
                        {trans.posTag} variant
                      </div>
                    </div>
                  ))}
                </div>
              ) : (
                <div style={{ padding: '1rem', background: 'var(--gray-100)', borderRadius: '4px' }}>
                  No results found
                </div>
              )}
            </div>
          </div>
        </div>
      )}

      {/* Regular Lookup Results */}
      {!compareMode && lookupResults && lookupResults.results && lookupResults.results.length > 0 && (
        <div style={{ marginBottom: '2rem' }}>
          <h3 style={{ marginBottom: '1rem' }}>Alternative Translations</h3>
          {lookupResults.results.map((result: any, idx: number) => (
            <div
              key={idx}
              style={{
                background: 'var(--gray-100)',
                padding: '1rem',
                borderRadius: 'var(--border-radius)',
                marginBottom: '1rem',
              }}
            >
              <div style={{ marginBottom: '0.5rem' }}>
                <strong style={{ fontSize: '1.125rem' }}>{result.displaySource}</strong>
                <span style={{ marginLeft: '0.5rem', color: 'var(--gray-700)' }}>
                  ({result.posTag})
                </span>
              </div>

              <div style={{ display: 'flex', flexDirection: 'column', gap: '0.5rem' }}>
                {result.translations?.map((trans: any, transIdx: number) => (
                  <div
                    key={transIdx}
                    style={{
                      background: 'white',
                      padding: '0.75rem',
                      borderRadius: '4px',
                      border: '1px solid var(--gray-300)',
                      display: 'flex',
                      justifyContent: 'space-between',
                      alignItems: 'center',
                    }}
                  >
                    <div>
                      <div style={{ fontSize: '1rem', fontWeight: 500 }}>
                        {trans.displayTarget}
                      </div>
                      {trans.posTag && (
                        <div style={{ fontSize: '0.875rem', color: 'var(--gray-700)' }}>
                          {trans.posTag} • Confidence: {(trans.confidence * 100).toFixed(0)}%
                        </div>
                      )}
                      {trans.backTranslations && trans.backTranslations.length > 0 && (
                        <div style={{ fontSize: '0.875rem', color: 'var(--gray-700)' }}>
                          Back: {trans.backTranslations.slice(0, 3).map((bt: any) => bt.displayText).join(', ')}
                        </div>
                      )}
                    </div>
                    <button
                      onClick={() => handleGetExamples(result.displaySource, trans.displayTarget)}
                      className="btn-secondary"
                      style={{ padding: '0.5rem 1rem', fontSize: '0.875rem' }}
                    >
                      📝 Examples
                    </button>
                  </div>
                ))}
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Examples */}
      {examples && examples.results && examples.results.length > 0 && (
        <div
          style={{
            background: 'var(--gray-100)',
            padding: '1.5rem',
            borderRadius: 'var(--border-radius)',
            border: '2px solid var(--azure-blue)',
          }}
        >
          <h3 style={{ marginBottom: '1rem' }}>
            Usage Examples for "{selectedTranslation?.text}" → "{selectedTranslation?.translation}"
          </h3>
          {examples.results[0]?.examples?.map((example: any, idx: number) => (
            <div
              key={idx}
              style={{
                background: 'white',
                padding: '1rem',
                borderRadius: '4px',
                marginBottom: '1rem',
                borderLeft: '4px solid var(--azure-blue)',
              }}
            >
              <div style={{ marginBottom: '0.5rem' }}>
                <div
                  style={{ fontSize: '1rem' }}
                  dangerouslySetInnerHTML={{ __html: example.sourcePrefix }}
                />
                <strong style={{ color: 'var(--azure-blue)' }}>{example.sourceTerm}</strong>
                <span
                  dangerouslySetInnerHTML={{ __html: example.sourceSuffix }}
                />
              </div>
              <div style={{ color: 'var(--gray-700)' }}>
                <div
                  style={{ fontSize: '1rem' }}
                  dangerouslySetInnerHTML={{ __html: example.targetPrefix }}
                />
                <strong style={{ color: 'var(--success)' }}>{example.targetTerm}</strong>
                <span
                  dangerouslySetInnerHTML={{ __html: example.targetSuffix }}
                />
              </div>
            </div>
          ))}
        </div>
      )}

      {!compareMode && lookupResults && lookupResults.results && lookupResults.results.length === 0 && (
        <div
          style={{
            padding: '1rem',
            background: 'var(--warning)',
            color: 'white',
            borderRadius: 'var(--border-radius)',
          }}
        >
          No dictionary entries found for "{word}". Try a different word or check the language pair.
        </div>
      )}
    </div>
  )
}

