import { useTranslation } from 'react-i18next'
import type { Language } from '../types/translator'

interface LanguageSelectorProps {
  id?: string
  value: string
  onChange: (value: string) => void
  languages?: Record<string, Language>
  includeAutoDetect?: boolean
}

export default function LanguageSelector({
  id,
  value,
  onChange,
  languages,
  includeAutoDetect = false,
}: LanguageSelectorProps) {
  const { t } = useTranslation()

  return (
    <select
      id={id}
      value={value}
      onChange={(e) => onChange(e.target.value)}
      aria-label="Select language"
    >
      {includeAutoDetect && (
        <option value="auto">{t('translator.autoDetect')}</option>
      )}
      {languages &&
        Object.entries(languages).map(([code, lang]) => (
          <option key={code} value={code}>
            {lang.name} ({lang.nativeName})
          </option>
        ))}
    </select>
  )
}

