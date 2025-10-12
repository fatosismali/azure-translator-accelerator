import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import TranslatorForm from './components/TranslatorForm'
import TranslationResult from './components/TranslationResult'
import DictionaryLookup from './components/DictionaryLookup'
import TranslationComparison from './components/TranslationComparison'
import BatchTranslation from './components/BatchTranslation'
import BatchReview from './components/BatchReview'
import ErrorBoundary from './components/ErrorBoundary'
import type { TranslateResponse } from './types/translator'
import './App.css'

function App() {
  const { t, i18n } = useTranslation()
  const [translationResult, setTranslationResult] = useState<TranslateResponse | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [activeTab, setActiveTab] = useState<'translate' | 'dictionary' | 'compare' | 'batch' | 'review'>('translate')

  const handleTranslationSuccess = (result: TranslateResponse) => {
    setTranslationResult(result)
    setError(null)
  }

  const handleTranslationError = (err: string) => {
    setError(err)
    setTranslationResult(null)
  }

  const toggleLanguage = () => {
    const newLang = i18n.language === 'en' ? 'es' : 'en'
    i18n.changeLanguage(newLang)
  }

  return (
    <ErrorBoundary>
      <div className="app">
        <header className="app-header">
          <div className="header-content">
            <div className="header-left">
              <h1>{t('app.title')}</h1>
              <p className="subtitle">{t('app.subtitle')}</p>
            </div>
            <div className="header-right">
              <button
                className="language-toggle"
                onClick={toggleLanguage}
                aria-label="Toggle language"
              >
                {i18n.language.toUpperCase()}
              </button>
            </div>
          </div>
        </header>

        <main className="app-main">
          <div className="container">
            {/* Tab Navigation */}
            <div className="tab-navigation" style={{ marginBottom: '2rem' }}>
              <button
                className={`tab-button ${activeTab === 'translate' ? 'active' : ''}`}
                onClick={() => setActiveTab('translate')}
                style={{
                  padding: '0.75rem 1.5rem',
                  border: 'none',
                  background: activeTab === 'translate' ? 'var(--azure-blue)' : 'var(--gray-200)',
                  color: activeTab === 'translate' ? 'white' : 'var(--gray-700)',
                  borderRadius: '8px 8px 0 0',
                  cursor: 'pointer',
                  fontWeight: 600,
                  marginRight: '0.5rem',
                }}
              >
                🌐 Translation
              </button>
              <button
                className={`tab-button ${activeTab === 'compare' ? 'active' : ''}`}
                onClick={() => setActiveTab('compare')}
                style={{
                  padding: '0.75rem 1.5rem',
                  border: 'none',
                  background: activeTab === 'compare' ? 'var(--azure-blue)' : 'var(--gray-200)',
                  color: activeTab === 'compare' ? 'white' : 'var(--gray-700)',
                  borderRadius: '8px 8px 0 0',
                  cursor: 'pointer',
                  fontWeight: 600,
                  marginRight: '0.5rem',
                }}
              >
                ⚖️ NMT vs LLM
              </button>
              <button
                className={`tab-button ${activeTab === 'dictionary' ? 'active' : ''}`}
                onClick={() => setActiveTab('dictionary')}
                style={{
                  padding: '0.75rem 1.5rem',
                  border: 'none',
                  background: activeTab === 'dictionary' ? 'var(--azure-blue)' : 'var(--gray-200)',
                  color: activeTab === 'dictionary' ? 'white' : 'var(--gray-700)',
                  borderRadius: '8px 8px 0 0',
                  cursor: 'pointer',
                  fontWeight: 600,
                  marginRight: '0.5rem',
                }}
              >
                📖 Dictionary
              </button>
              <button
                className={`tab-button ${activeTab === 'batch' ? 'active' : ''}`}
                onClick={() => setActiveTab('batch')}
                style={{
                  padding: '0.75rem 1.5rem',
                  border: 'none',
                  background: activeTab === 'batch' ? 'var(--azure-blue)' : 'var(--gray-200)',
                  color: activeTab === 'batch' ? 'white' : 'var(--gray-700)',
                  borderRadius: '8px 8px 0 0',
                  cursor: 'pointer',
                  fontWeight: 600,
                  marginRight: '0.5rem',
                }}
              >
                📦 Batch
              </button>
              <button
                className={`tab-button ${activeTab === 'review' ? 'active' : ''}`}
                onClick={() => setActiveTab('review')}
                style={{
                  padding: '0.75rem 1.5rem',
                  border: 'none',
                  background: activeTab === 'review' ? 'var(--azure-blue)' : 'var(--gray-200)',
                  color: activeTab === 'review' ? 'white' : 'var(--gray-700)',
                  borderRadius: '8px 8px 0 0',
                  cursor: 'pointer',
                  fontWeight: 600,
                }}
              >
                📊 Review
              </button>
            </div>

            {/* Translation Tab */}
            {activeTab === 'translate' && (
              <>
                <TranslatorForm
                  onSuccess={handleTranslationSuccess}
                  onError={handleTranslationError}
                />

                {error && (
                  <div className="error-message" role="alert">
                    <strong>Error:</strong> {error}
                  </div>
                )}

                {translationResult && (
                  <TranslationResult result={translationResult} />
                )}
              </>
            )}

            {/* Comparison Tab */}
            {activeTab === 'compare' && (
              <div style={{ 
                background: 'white',
                borderRadius: 'var(--border-radius)',
                padding: '2rem',
                boxShadow: 'var(--box-shadow)',
              }}>
                <TranslationComparison />
              </div>
            )}

            {/* Dictionary Tab */}
            {activeTab === 'dictionary' && (
              <div style={{ 
                background: 'white',
                borderRadius: 'var(--border-radius)',
                padding: '2rem',
                boxShadow: 'var(--box-shadow)',
              }}>
                <DictionaryLookup />
              </div>
            )}

            {/* Batch Translation Tab */}
            {activeTab === 'batch' && (
              <div style={{ 
                background: 'white',
                borderRadius: 'var(--border-radius)',
                padding: '2rem',
                boxShadow: 'var(--box-shadow)',
              }}>
                <BatchTranslation />
              </div>
            )}

            {/* Batch Review Tab */}
            {activeTab === 'review' && (
              <div style={{ 
                background: 'white',
                borderRadius: 'var(--border-radius)',
                padding: '2rem',
                boxShadow: 'var(--box-shadow)',
              }}>
                <BatchReview />
              </div>
            )}
          </div>
        </main>

        <footer className="app-footer">
          <div className="container">
            <p>{t('footer.poweredBy')}</p>
            <p className="version">{t('footer.version', { version: '1.0.0' })}</p>
          </div>
        </footer>
      </div>
    </ErrorBoundary>
  )
}

export default App

