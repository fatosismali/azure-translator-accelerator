import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useMutation, useQuery } from '@tanstack/react-query'
import translatorAPI from '../services/api'
import { trackEvent, trackException } from '../services/telemetry'
import type { TranslateResponse, LanguagesResponse } from '../types/translator'
import LanguageSelector from './LanguageSelector'

interface TranslatorFormProps {
  onSuccess: (result: TranslateResponse) => void
  onError: (error: string) => void
}

export default function TranslatorForm({ onSuccess, onError }: TranslatorFormProps) {
  const { t } = useTranslation()
  const [text, setText] = useState('')
  const [sourceLang, setSourceLang] = useState('auto')
  const [targetLangs, setTargetLangs] = useState<string[]>(['es'])

  // Fetch supported languages
  const { data: languages } = useQuery({
    queryKey: ['languages'],
    queryFn: () => translatorAPI.getLanguages(),
    staleTime: 60 * 60 * 1000, // 1 hour
  })

  // Translation mutation
  const translateMutation = useMutation({
    mutationFn: async () => {
      return translatorAPI.translate({
        text,
        to: targetLangs,
        from: sourceLang === 'auto' ? undefined : sourceLang,
      })
    },
    onSuccess: (data) => {
      onSuccess(data)
      trackEvent('Translation_Success', {
        sourceLang: sourceLang === 'auto' ? 'auto-detected' : sourceLang,
        targetLangs: targetLangs.join(','),
        textLength: text.length,
      })
    },
    onError: (error: any) => {
      const errorMsg = error.response?.data?.detail || t('errors.apiError')
      onError(errorMsg)
      trackException(error, { operation: 'translation' })
    },
  })

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()

    if (!text.trim()) {
      onError(t('errors.invalidInput'))
      return
    }

    if (text.length > 50000) {
      onError(t('errors.textTooLong'))
      return
    }

    if (targetLangs.length === 0) {
      onError(t('errors.noTargetLanguage'))
      return
    }

    translateMutation.mutate()
  }

  const handleClear = () => {
    setText('')
    setSourceLang('auto')
    setTargetLangs(['es'])
    onError('')
  }

  const characterCount = text.length

  return (
    <form className="translator-form" onSubmit={handleSubmit}>
      <div className="form-group">
        <label htmlFor="source-text">{t('translator.inputPlaceholder')}</label>
        <div className="textarea-wrapper">
          <textarea
            id="source-text"
            value={text}
            onChange={(e) => setText(e.target.value)}
            placeholder={t('translator.inputPlaceholder')}
            maxLength={50000}
            aria-label="Input text to translate"
            aria-describedby="character-count"
          />
          <span id="character-count" className="character-count">
            {t('translator.characterCount', { count: characterCount })}
          </span>
        </div>
      </div>

      <div className="form-group">
        <label htmlFor="source-lang">{t('translator.sourceLang')}</label>
        <LanguageSelector
          id="source-lang"
          value={sourceLang}
          onChange={setSourceLang}
          languages={languages?.translation}
          includeAutoDetect
        />
      </div>

      <div className="form-group">
        <label htmlFor="target-lang">{t('translator.targetLang')}</label>
        <select
          id="target-lang"
          value={targetLangs[0]}
          onChange={(e) => setTargetLangs([e.target.value])}
          aria-label="Select target language"
        >
          {languages?.translation &&
            Object.entries(languages.translation).map(([code, lang]) => (
              <option key={code} value={code}>
                {lang.name} ({lang.nativeName})
              </option>
            ))}
        </select>
      </div>

      <div className="form-actions">
        <button
          type="submit"
          className="btn-primary"
          disabled={translateMutation.isPending || !text.trim()}
          aria-label={t('translator.translate')}
        >
          {translateMutation.isPending ? t('translator.translating') : t('translator.translate')}
        </button>
        <button
          type="button"
          className="btn-secondary"
          onClick={handleClear}
          aria-label={t('translator.clear')}
        >
          {t('translator.clear')}
        </button>
      </div>
    </form>
  )
}

