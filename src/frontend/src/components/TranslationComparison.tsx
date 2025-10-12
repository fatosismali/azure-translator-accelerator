import { useState, useEffect } from 'react'
import { useTranslation } from 'react-i18next'
import { useMutation, useQuery } from '@tanstack/react-query'
import { trackEvent } from '../services/telemetry'
import { translatorAPI } from '../services/api'

interface ComparisonResult {
  request_id: string
  source_text: string
  source_language: string
  target_language: string
  nmt: {
    translation: any
    error: string | null
    model: string
    api_version: string
  }
  llm: {
    translation: any
    error: string | null
    model: string
    api_version: string
    tone: string | null
    gender: string | null
  }
}

export default function TranslationComparison() {
  const { t } = useTranslation()
  const [text, setText] = useState('')
  const [fromLang, setFromLang] = useState('en')
  const [toLang, setToLang] = useState('es')
  const [llmModel, setLlmModel] = useState('gpt-4o-mini')
  const [tone, setTone] = useState<string>('')
  const [gender, setGender] = useState<string>('')
  const [comparisonResult, setComparisonResult] = useState<ComparisonResult | null>(null)

  // Fetch supported languages
  const { data: languagesData } = useQuery({
    queryKey: ['languages', 'translation'],
    queryFn: () => translatorAPI.getLanguages('translation'),
  })

  // Extract and sort languages for dropdowns
  const supportedLanguages = languagesData?.translation
    ? Object.entries(languagesData.translation)
        .map(([code, info]: [string, any]) => ({
          code,
          name: info.name,
          nativeName: info.nativeName,
        }))
        .sort((a, b) => a.name.localeCompare(b.name))
    : []

  const compareMutation = useMutation({
    mutationFn: async () => {
      return await translatorAPI.compareTranslations(
        text,
        toLang,
        fromLang || undefined,
        llmModel,
        tone || undefined,
        gender || undefined
      )
    },
    onSuccess: (data) => {
      setComparisonResult(data)
      trackEvent('Translation_Comparison', {
        source_lang: fromLang,
        target_lang: toLang,
        llm_model: llmModel,
        tone,
        gender,
      })
    },
    onError: (error: any) => {
      console.error('Comparison error:', error)
    },
  })

  const handleCompare = (e: React.FormEvent) => {
    e.preventDefault()
    if (text.trim()) {
      compareMutation.mutate()
    }
  }

  const getNmtTranslationText = () => {
    if (!comparisonResult?.nmt?.translation) return null
    return comparisonResult.nmt.translation.translations?.[0]?.text || 'N/A'
  }

  const getLlmTranslationText = () => {
    if (!comparisonResult?.llm?.translation) return null
    return comparisonResult.llm.translation.translations?.[0]?.text || 'N/A'
  }

  return (
    <div className="translation-comparison">
      <h2 style={{ marginBottom: '1rem', color: 'var(--azure-blue)' }}>
        ⚖️ NMT vs LLM Translation Comparison
      </h2>
      <p style={{ marginBottom: '1.5rem', color: 'var(--gray-700)' }}>
        Compare traditional Neural Machine Translation with advanced LLM-powered translation
        side-by-side
      </p>

      <form onSubmit={handleCompare} style={{ marginBottom: '2rem' }}>
        <div className="form-group">
          <label htmlFor="compare-text">Text to Translate</label>
          <textarea
            id="compare-text"
            value={text}
            onChange={(e) => setText(e.target.value)}
            placeholder="Enter text to compare translations (e.g., 'The meeting will take place tomorrow at 3 PM.')"
            rows={4}
            style={{
              width: '100%',
              padding: '0.75rem',
              border: '1px solid var(--gray-300)',
              borderRadius: 'var(--border-radius)',
              fontSize: '1rem',
              fontFamily: 'inherit',
              resize: 'vertical',
            }}
          />
          <div style={{ fontSize: '0.875rem', color: 'var(--gray-700)', marginTop: '0.25rem' }}>
            {text.length} / 5000 characters
          </div>
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
          <div className="form-group">
            <label htmlFor="compare-from">From Language</label>
            <select
              id="compare-from"
              value={fromLang}
              onChange={(e) => setFromLang(e.target.value)}
            >
              <option value="">Auto-detect</option>
              {supportedLanguages.map((lang) => (
                <option key={lang.code} value={lang.code}>
                  {lang.name} ({lang.nativeName})
                </option>
              ))}
            </select>
          </div>

          <div className="form-group">
            <label htmlFor="compare-to">To Language</label>
            <select id="compare-to" value={toLang} onChange={(e) => setToLang(e.target.value)}>
              {supportedLanguages.map((lang) => (
                <option key={lang.code} value={lang.code}>
                  {lang.name} ({lang.nativeName})
                </option>
              ))}
            </select>
          </div>
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: '1rem' }}>
          <div className="form-group">
            <label htmlFor="llm-model">LLM Model</label>
            <select
              id="llm-model"
              value={llmModel}
              onChange={(e) => setLlmModel(e.target.value)}
            >
              <option value="gpt-4o-mini">GPT-4o Mini (faster, cheaper)</option>
              <option value="gpt-4o">GPT-4o (highest quality)</option>
            </select>
          </div>

          <div className="form-group">
            <label htmlFor="tone">Tone (LLM Only)</label>
            <select id="tone" value={tone} onChange={(e) => setTone(e.target.value)}>
              <option value="">Default</option>
              <option value="formal">Formal</option>
              <option value="informal">Informal</option>
              <option value="neutral">Neutral</option>
            </select>
          </div>

          <div className="form-group">
            <label htmlFor="gender">Gender (LLM Only)</label>
            <select id="gender" value={gender} onChange={(e) => setGender(e.target.value)}>
              <option value="">Default</option>
              <option value="male">Male</option>
              <option value="female">Female</option>
              <option value="neutral">Neutral</option>
            </select>
          </div>
        </div>

        <button
          type="submit"
          className="btn-primary"
          disabled={compareMutation.isPending || !text.trim()}
          style={{ marginTop: '1rem' }}
        >
          {compareMutation.isPending ? '⏳ Comparing...' : '⚖️ Compare Translations'}
        </button>
      </form>

      {/* Comparison Results */}
      {comparisonResult && (
        <div style={{ marginTop: '2rem' }}>
          <h3 style={{ marginBottom: '1.5rem' }}>Comparison Results</h3>

          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1.5rem' }}>
            {/* NMT Result */}
            <div
              style={{
                background: 'var(--gray-100)',
                padding: '1.5rem',
                borderRadius: 'var(--border-radius)',
                border: '2px solid var(--gray-400)',
              }}
            >
              <div style={{ marginBottom: '1rem' }}>
                <h4 style={{ color: 'var(--gray-800)', marginBottom: '0.5rem' }}>
                  🧠 Neural Machine Translation (NMT)
                </h4>
                <div style={{ fontSize: '0.875rem', color: 'var(--gray-700)' }}>
                  API: {comparisonResult.nmt.api_version} • Fast • Cost-effective
                </div>
              </div>

              {comparisonResult.nmt.error ? (
                <div
                  style={{
                    background: '#fee',
                    color: '#c33',
                    padding: '1rem',
                    borderRadius: '4px',
                  }}
                >
                  ❌ Error: {comparisonResult.nmt.error}
                </div>
              ) : (
                <div
                  style={{
                    background: 'white',
                    padding: '1rem',
                    borderRadius: '4px',
                    fontSize: '1.125rem',
                    lineHeight: '1.6',
                    minHeight: '100px',
                  }}
                >
                  {getNmtTranslationText()}
                </div>
              )}

              <div
                style={{
                  marginTop: '1rem',
                  padding: '0.75rem',
                  background: 'white',
                  borderRadius: '4px',
                  fontSize: '0.875rem',
                }}
              >
                <div>
                  <strong>✅ Pros:</strong>
                </div>
                <ul style={{ marginTop: '0.5rem', paddingLeft: '1.5rem' }}>
                  <li>Lightning fast response</li>
                  <li>Lower cost per character</li>
                  <li>Up to 50K chars per request</li>
                  <li>Proven reliability</li>
                </ul>
              </div>
            </div>

            {/* LLM Result */}
            <div
              style={{
                background: 'linear-gradient(135deg, #e0f2fe 0%, #dbeafe 100%)',
                padding: '1.5rem',
                borderRadius: 'var(--border-radius)',
                border: '2px solid var(--azure-blue)',
              }}
            >
              <div style={{ marginBottom: '1rem' }}>
                <h4 style={{ color: 'var(--azure-blue)', marginBottom: '0.5rem' }}>
                  🤖 LLM Translation ({comparisonResult.llm.model})
                </h4>
                <div style={{ fontSize: '0.875rem', color: 'var(--gray-700)' }}>
                  API: {comparisonResult.llm.api_version}
                  {comparisonResult.llm.tone && ` • Tone: ${comparisonResult.llm.tone}`}
                  {comparisonResult.llm.gender && ` • Gender: ${comparisonResult.llm.gender}`}
                </div>
              </div>

              {comparisonResult.llm.error ? (
                <div
                  style={{
                    background: '#fee',
                    color: '#c33',
                    padding: '1rem',
                    borderRadius: '4px',
                  }}
                >
                  ❌ Error: {comparisonResult.llm.error}
                </div>
              ) : (
                <div
                  style={{
                    background: 'white',
                    padding: '1rem',
                    borderRadius: '4px',
                    fontSize: '1.125rem',
                    lineHeight: '1.6',
                    minHeight: '100px',
                    boxShadow: '0 2px 4px rgba(0,0,0,0.1)',
                  }}
                >
                  {getLlmTranslationText()}
                </div>
              )}

              <div
                style={{
                  marginTop: '1rem',
                  padding: '0.75rem',
                  background: 'white',
                  borderRadius: '4px',
                  fontSize: '0.875rem',
                }}
              >
                <div>
                  <strong>✨ Pros:</strong>
                </div>
                <ul style={{ marginTop: '0.5rem', paddingLeft: '1.5rem' }}>
                  <li>Better context understanding</li>
                  <li>Tone control (formal/informal)</li>
                  <li>Gender-specific translation</li>
                  <li>Adaptive custom translation</li>
                  <li>More natural phrasing</li>
                </ul>
              </div>
            </div>
          </div>

          {/* Analysis Section */}
          {!comparisonResult.nmt.error && !comparisonResult.llm.error && (
            <div
              style={{
                marginTop: '2rem',
                padding: '1.5rem',
                background: 'var(--gray-100)',
                borderRadius: 'var(--border-radius)',
                border: '1px solid var(--gray-300)',
              }}
            >
              <h4 style={{ marginBottom: '1rem' }}>📊 Analysis</h4>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: '1rem' }}>
                <div>
                  <strong>Character Count:</strong>
                  <div style={{ fontSize: '0.875rem', color: 'var(--gray-700)' }}>
                    Source: {comparisonResult.source_text.length} chars
                  </div>
                  <div style={{ fontSize: '0.875rem', color: 'var(--gray-700)' }}>
                    NMT: {getNmtTranslationText()?.length || 0} chars
                  </div>
                  <div style={{ fontSize: '0.875rem', color: 'var(--gray-700)' }}>
                    LLM: {getLlmTranslationText()?.length || 0} chars
                  </div>
                </div>

                <div>
                  <strong>Best For:</strong>
                  <div style={{ fontSize: '0.875rem', color: 'var(--gray-700)' }}>
                    NMT: High-volume, cost-sensitive
                  </div>
                  <div style={{ fontSize: '0.875rem', color: 'var(--gray-700)' }}>
                    LLM: Quality-critical, contextual
                  </div>
                </div>

                <div>
                  <strong>Cost Estimate:</strong>
                  <div style={{ fontSize: '0.875rem', color: 'var(--gray-700)' }}>
                    NMT: ~$0.01 per 1K chars
                  </div>
                  <div style={{ fontSize: '0.875rem', color: 'var(--gray-700)' }}>
                    LLM: ~$0.10-0.50 per 1K tokens
                  </div>
                </div>
              </div>
            </div>
          )}
        </div>
      )}

      {compareMutation.isError && (
        <div
          style={{
            marginTop: '1rem',
            padding: '1rem',
            background: '#fee',
            color: '#c33',
            borderRadius: 'var(--border-radius)',
          }}
        >
          ❌ Error: {(compareMutation.error as any)?.response?.data?.detail || 'Comparison failed'}
        </div>
      )}

      {/* Info Box */}
      <div
        style={{
          marginTop: '2rem',
          padding: '1rem',
          background: '#fffbeb',
          border: '1px solid #fcd34d',
          borderRadius: 'var(--border-radius)',
        }}
      >
        <strong>ℹ️ Note:</strong> LLM translation requires an Azure AI Foundry resource. If you
        see errors for LLM translation, ensure you have set up the Azure AI Foundry endpoint and
        API key in your environment variables.
      </div>
    </div>
  )
}

