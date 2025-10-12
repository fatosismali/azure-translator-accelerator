import { useTranslation } from 'react-i18next'
import type { TranslateResponse } from '../types/translator'

interface TranslationResultProps {
  result: TranslateResponse
}

export default function TranslationResult({ result }: TranslationResultProps) {
  const { t } = useTranslation()

  if (!result || result.translations.length === 0) {
    return (
      <div className="translation-results">
        <p>{t('results.noResults')}</p>
      </div>
    )
  }

  return (
    <div className="translation-results">
      <h2>{t('results.title')}</h2>
      
      {result.translations.map((item, itemIndex) => (
        <div key={itemIndex}>
          {item.detectedLanguage && (
            <div className="detected-language">
              {t('results.detected')}: <strong>{item.detectedLanguage.language}</strong>
              {' '}({t('results.confidence')}: {(item.detectedLanguage.score * 100).toFixed(0)}%)
            </div>
          )}
          
          {item.translations.map((translation, transIndex) => (
            <div key={transIndex} className="result-item">
              <div className="result-header">
                <span className="language-badge">{translation.to.toUpperCase()}</span>
              </div>
              <div className="result-text">{translation.text}</div>
            </div>
          ))}
        </div>
      ))}
      
      {result.request_id && (
        <p className="request-id" style={{ fontSize: '0.75rem', opacity: 0.6, marginTop: '1rem' }}>
          Request ID: {result.request_id}
        </p>
      )}
    </div>
  )
}

