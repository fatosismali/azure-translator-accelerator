/**
 * TypeScript types for Azure Translator API
 */

export interface TranslateRequest {
  text: string | string[]
  to: string[]
  from?: string
  textType?: 'plain' | 'html'
  category?: string
  profanityAction?: string
  profanityMarker?: string
  includeAlignment?: boolean
  includeSentenceLength?: boolean
}

export interface Translation {
  text: string
  to: string
}

export interface DetectedLanguage {
  language: string
  score: number
}

export interface TranslationItem {
  detectedLanguage?: DetectedLanguage
  translations: Translation[]
}

export interface TranslateResponse {
  translations: TranslationItem[]
  request_id?: string
}

export interface DetectRequest {
  text: string | string[]
}

export interface DetectedLanguageInfo {
  language: string
  score: number
  isTranslationSupported: boolean
  isTransliterationSupported: boolean
  alternatives?: Array<{
    language: string
    score: number
    isTranslationSupported: boolean
    isTransliterationSupported: boolean
  }>
}

export interface DetectResponse {
  detections: DetectedLanguageInfo[]
  request_id?: string
}

export interface Language {
  name: string
  nativeName: string
  dir: 'ltr' | 'rtl'
}

export interface LanguagesResponse {
  translation: Record<string, Language>
  transliteration?: Record<string, any>
  dictionary?: Record<string, any>
}

export interface ErrorResponse {
  detail: string | any[]
  message?: string
}

