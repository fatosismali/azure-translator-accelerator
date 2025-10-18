/**
 * API client for Azure Translator backend
 */

import axios, { AxiosInstance, AxiosError } from 'axios'
import type {
  TranslateRequest,
  TranslateResponse,
  DetectRequest,
  DetectResponse,
  LanguagesResponse,
  ErrorResponse,
} from '../types/translator'

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8000'
const API_V1_PREFIX = '/api/v1'

class TranslatorAPI {
  private client: AxiosInstance

  constructor() {
    this.client = axios.create({
      baseURL: `${API_BASE_URL}${API_V1_PREFIX}`,
      timeout: 30000,
      headers: {
        'Content-Type': 'application/json',
      },
    })

    // Request interceptor
    this.client.interceptors.request.use(
      config => {
        console.log(`[API] ${config.method?.toUpperCase()} ${config.url}`)
        return config
      },
      error => {
        return Promise.reject(error)
      }
    )

    // Response interceptor
    this.client.interceptors.response.use(
      response => {
        return response
      },
      (error: AxiosError<ErrorResponse>) => {
        console.error('[API Error]', error.response?.data || error.message)
        return Promise.reject(error)
      }
    )
  }

  /**
   * Translate text to one or more target languages
   */
  async translate(request: TranslateRequest): Promise<TranslateResponse> {
    const response = await this.client.post<TranslateResponse>('/translate', request)
    return response.data
  }

  /**
   * Detect the language of input text
   */
  async detect(request: DetectRequest): Promise<DetectResponse> {
    const response = await this.client.post<DetectResponse>('/detect', request)
    return response.data
  }

  /**
   * Get supported languages
   */
  async getLanguages(scope: string = 'translation'): Promise<LanguagesResponse> {
    const response = await this.client.get<LanguagesResponse>('/languages', {
      params: { scope },
    })
    return response.data
  }

  /**
   * Dictionary lookup - get alternative translations
   */
  async dictionaryLookup(text: string, fromLang: string, toLang: string): Promise<any> {
    const response = await this.client.post('/dictionary/lookup', {
      text,
      from: fromLang,
      to: toLang,
    })
    return response.data
  }

  /**
   * Dictionary examples - get usage examples for translations
   */
  async dictionaryExamples(
    text: string,
    translation: string,
    fromLang: string,
    toLang: string
  ): Promise<any> {
    const response = await this.client.post('/dictionary/examples', {
      text,
      translation,
      from: fromLang,
      to: toLang,
    })
    return response.data
  }

  /**
   * Translate with LLM (GPT-4o-mini or GPT-4o) using 2025-05-01-preview API
   */
  async translateWithLLM(
    text: string,
    to: string[],
    fromLang?: string,
    model: string = 'gpt-4o-mini',
    tone?: string,
    gender?: string
  ): Promise<any> {
    const response = await this.client.post('/translate/llm', {
      text,
      to,
      from: fromLang || undefined,
      model,
      tone: tone || undefined,
      gender: gender || undefined,
    })
    return response.data
  }

  /**
   * Compare NMT and LLM translations side-by-side
   */
  async compareTranslations(
    text: string,
    to: string,
    fromLang?: string,
    llmModel: string = 'gpt-4o-mini',
    tone?: string,
    gender?: string
  ): Promise<any> {
    const response = await this.client.post('/translate/compare', {
      text,
      to,
      from: fromLang || undefined,
      llm_model: llmModel,
      tone: tone || undefined,
      gender: gender || undefined,
    })
    return response.data
  }

  /**
   * Compare NMT and LLM dictionary lookups side-by-side
   */
  async compareDictionary(
    text: string,
    fromLang: string,
    toLang: string
  ): Promise<any> {
    const response = await this.client.post('/dictionary/compare', {
      text,
      from: fromLang,
      to: toLang,
    })
    return response.data
  }

  /**
   * Health check
   */
  async healthCheck(): Promise<{ status: string; version: string; timestamp: string }> {
    const response = await this.client.get('../../health')
    return response.data
  }

  // ========================================================================
  // BATCH TRANSLATION
  // ========================================================================

  /**
   * List all blob storage containers
   */
  async listContainers(): Promise<any> {
    const response = await this.client.get('/batch/containers')
    return response.data
  }

  /**
   * List files in a container
   */
  async listContainerFiles(containerName: string): Promise<any> {
    const response = await this.client.get(`/batch/containers/${containerName}/files`)
    return response.data
  }

  /**
   * Start a batch translation job
   */
  async startBatchJob(
    sourceContainer: string,
    targetContainer: string,
    targetLanguage: string,
    sourceLanguage?: string,
    dictionary?: Record<string, string>
  ): Promise<any> {
    const response = await this.client.post('/batch/jobs', {
      source_container: sourceContainer,
      target_container: targetContainer,
      target_language: targetLanguage,
      source_language: sourceLanguage,
      dictionary: dictionary,
    })
    return response.data
  }

  /**
   * Get batch job status
   */
  async getBatchJobStatus(jobId: string): Promise<any> {
    const response = await this.client.get(`/batch/jobs/${jobId}`)
    return response.data
  }

  /**
   * List translated files in a container
   */
  async listTranslatedFiles(containerName: string): Promise<any> {
    const response = await this.client.get(`/batch/translations/${containerName}`)
    return response.data
  }

  /**
   * Get evaluation data (source + NMT + LLM) for all files
   */
  async getEvaluationData(sourceContainer: string, targetContainer: string): Promise<any> {
    const response = await this.client.get(`/batch/evaluate/${sourceContainer}/${targetContainer}`)
    return response.data
  }

  /**
   * Get translations for a specific file
   */
  async getFileTranslations(containerName: string, filename: string): Promise<any> {
    const response = await this.client.get(
      `/batch/translations/${containerName}/file?filename=${encodeURIComponent(filename)}`
    )
    return response.data
  }

  /**
   * Submit a rating for a translation
   */
  async submitRating(
    filename: string,
    container: string,
    nmtBlob: string,
    llmBlob: string,
    preferred: 'nmt' | 'llm',
    comments?: string
  ): Promise<any> {
    const response = await this.client.post('/ratings', {
      filename,
      container,
      nmt_blob: nmtBlob,
      llm_blob: llmBlob,
      preferred,
      comments,
    })
    return response.data
  }

  /**
   * Get rating statistics
   */
  async getRatingStats(): Promise<any> {
    const response = await this.client.get('/ratings/stats')
    return response.data
  }

  /**
   * List all ratings
   */
  async listRatings(): Promise<any> {
    const response = await this.client.get('/ratings/list')
    return response.data
  }
}

export const translatorAPI = new TranslatorAPI()
export default translatorAPI

