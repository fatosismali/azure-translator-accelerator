import { useState, useEffect } from 'react'
import { useTranslation } from 'react-i18next'
import { useMutation, useQuery } from '@tanstack/react-query'
import translatorAPI from '../services/api'
import { trackEvent } from '../services/telemetry'

export default function BatchTranslation() {
  const { t } = useTranslation()
  const [sourceContainer, setSourceContainer] = useState('')
  const [targetContainer, setTargetContainer] = useState('')
  const [targetLanguage, setTargetLanguage] = useState('es')
  const [sourceLanguage, setSourceLanguage] = useState('')
  const [jobStatus, setJobStatus] = useState<any>(null)
  const [jobId, setJobId] = useState<string | null>(null)

  // Fetch containers
  const {
    data: containersData,
    isLoading: containersLoading,
    refetch: refetchContainers,
  } = useQuery({
    queryKey: ['containers'],
    queryFn: () => translatorAPI.listContainers(),
  })

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

  // Fetch files from source container
  const {
    data: filesData,
    isLoading: filesLoading,
    refetch: refetchFiles,
  } = useQuery({
    queryKey: ['container-files', sourceContainer],
    queryFn: () => translatorAPI.listContainerFiles(sourceContainer),
    enabled: !!sourceContainer,
  })

  // Start batch job mutation
  const startJobMutation = useMutation({
    mutationFn: async () => {
      return translatorAPI.startBatchJob(
        sourceContainer,
        targetContainer,
        targetLanguage,
        sourceLanguage || undefined
      )
    },
    onSuccess: (data) => {
      setJobStatus(data)
      setJobId(data.job_id)
      trackEvent('Batch_Job_Started', {
        jobId: data.job_id,
        totalFiles: data.total_files,
      })
    },
    onError: (error: any) => {
      console.error('Batch job error:', error)
    },
  })

  // Poll job status
  const checkStatusMutation = useMutation({
    mutationFn: async (id: string) => {
      return translatorAPI.getBatchJobStatus(id)
    },
    onSuccess: (data) => {
      setJobStatus((prev: any) => ({ ...prev, ...data }))
    },
  })

  const handleStartJob = () => {
    if (!sourceContainer || !targetContainer || !targetLanguage) {
      return
    }
    
    if (sourceContainer === targetContainer) {
      alert('❌ Error: Source and target containers must be different to avoid overwriting source files.')
      return
    }
    
    startJobMutation.mutate()
  }

  const handleCheckStatus = () => {
    if (jobId) {
      checkStatusMutation.mutate(jobId)
    }
  }

  return (
    <div className="batch-translation">
      <h2 style={{ marginBottom: '1rem', color: 'var(--azure-blue)' }}>
        📦 Batch Translation
      </h2>
      <p style={{ marginBottom: '1.5rem', color: 'var(--gray-700)' }}>
        Translate multiple text files from blob storage using both NMT and LLM
      </p>

      {/* Container Selection */}
      <div style={{ marginBottom: '2rem' }}>
        <h3 style={{ marginBottom: '1rem' }}>Step 1: Select Containers</h3>
        
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem', marginBottom: '1rem' }}>
          <div>
            <label htmlFor="source-container">Source Container (with .txt files)</label>
            <select
              id="source-container"
              value={sourceContainer}
              onChange={(e) => setSourceContainer(e.target.value)}
              disabled={containersLoading}
              style={{
                width: '100%',
                padding: '0.75rem',
                border: sourceContainer && sourceContainer === targetContainer 
                  ? '2px solid #ef4444' 
                  : '1px solid var(--gray-300)',
                borderRadius: 'var(--border-radius)',
              }}
            >
              <option value="">Select source container...</option>
              {containersData?.containers.map((container: string) => (
                <option key={container} value={container}>
                  {container}
                </option>
              ))}
            </select>
            {sourceContainer && filesData && (
              <div style={{ marginTop: '0.5rem', fontSize: '0.9rem', color: 'var(--gray-600)' }}>
                📁 Found {filesData.files.length} text file(s)
              </div>
            )}
          </div>

          <div>
            <label htmlFor="target-container">Target Container (for translations)</label>
            <select
              id="target-container"
              value={targetContainer}
              onChange={(e) => setTargetContainer(e.target.value)}
              disabled={containersLoading}
              style={{
                width: '100%',
                padding: '0.75rem',
                border: sourceContainer && sourceContainer === targetContainer 
                  ? '2px solid #ef4444' 
                  : '1px solid var(--gray-300)',
                borderRadius: 'var(--border-radius)',
              }}
            >
              <option value="">Select target container...</option>
              {containersData?.containers.map((container: string) => (
                <option key={container} value={container}>
                  {container}
                </option>
              ))}
            </select>
            {sourceContainer && sourceContainer === targetContainer ? (
              <div style={{ marginTop: '0.5rem', padding: '0.5rem', backgroundColor: '#fee2e2', borderRadius: '4px', fontSize: '0.85rem', color: '#991b1b' }}>
                ❌ ERROR: Source and target must be different containers
              </div>
            ) : targetContainer && (
              <div style={{ marginTop: '0.5rem', fontSize: '0.85rem', color: 'var(--gray-600)' }}>
                ℹ️ Translations will be stored in /nmt and /llm subdirectories
              </div>
            )}
          </div>
        </div>

        {sourceContainer && filesData && (
          <div
            style={{
              padding: '1rem',
              background: 'var(--gray-100)',
              borderRadius: 'var(--border-radius)',
              marginBottom: '1rem',
            }}
          >
            <strong>📄 Found {filesData.total} text file(s) in {sourceContainer}</strong>
            {filesData.files.slice(0, 5).map((file: any) => (
              <div key={file.name} style={{ fontSize: '0.875rem', color: 'var(--gray-700)' }}>
                • {file.name} ({Math.round(file.size / 1024)} KB)
              </div>
            ))}
            {filesData.files.length > 5 && (
              <div style={{ fontSize: '0.875rem', color: 'var(--gray-600)', marginTop: '0.5rem' }}>
                ... and {filesData.files.length - 5} more files
              </div>
            )}
          </div>
        )}
      </div>

      {/* Language Selection */}
      <div style={{ marginBottom: '2rem' }}>
        <h3 style={{ marginBottom: '1rem' }}>Step 2: Select Languages</h3>
        
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
          <div>
            <label htmlFor="source-lang">Source Language (optional)</label>
            <select
              id="source-lang"
              value={sourceLanguage}
              onChange={(e) => setSourceLanguage(e.target.value)}
              style={{
                width: '100%',
                padding: '0.75rem',
                border: '1px solid var(--gray-300)',
                borderRadius: 'var(--border-radius)',
              }}
            >
              <option value="">Auto-detect</option>
              {supportedLanguages.map((lang) => (
                <option key={lang.code} value={lang.code}>
                  {lang.name} ({lang.nativeName})
                </option>
              ))}
            </select>
          </div>

          <div>
            <label htmlFor="target-lang">Target Language *</label>
            <select
              id="target-lang"
              value={targetLanguage}
              onChange={(e) => setTargetLanguage(e.target.value)}
              style={{
                width: '100%',
                padding: '0.75rem',
                border: '1px solid var(--gray-300)',
                borderRadius: 'var(--border-radius)',
              }}
            >
              {supportedLanguages.map((lang) => (
                <option key={lang.code} value={lang.code}>
                  {lang.name} ({lang.nativeName})
                </option>
              ))}
            </select>
          </div>
        </div>
      </div>

      {/* Start Job */}
      <div style={{ marginBottom: '2rem' }}>
        <h3 style={{ marginBottom: '1rem' }}>Step 3: Start Batch Job</h3>
        
        <button
          onClick={handleStartJob}
          disabled={!sourceContainer || !targetContainer || !targetLanguage || startJobMutation.isPending}
          className="btn-primary"
          style={{ width: '100%' }}
        >
          {startJobMutation.isPending ? '⏳ Processing translations... Please wait...' : '🚀 Start Batch Translation'}
        </button>
        
        {startJobMutation.isPending && (
          <div style={{ marginTop: '1rem', padding: '1rem', background: '#fff3cd', borderRadius: 'var(--border-radius)' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', marginBottom: '0.5rem' }}>
              <div className="spinner" style={{ width: '20px', height: '20px' }}></div>
              <strong>Processing files...</strong>
            </div>
            <p style={{ fontSize: '0.875rem', color: 'var(--gray-700)', margin: 0 }}>
              Translating with both NMT and LLM (GPT-4o-mini). This may take a few moments.
            </p>
          </div>
        )}
      </div>

      {/* Job Status */}
      {jobStatus && (
        <div
          style={{
            padding: '1.5rem',
            background: 'white',
            border: '2px solid var(--azure-blue)',
            borderRadius: 'var(--border-radius)',
          }}
        >
          <h3 style={{ marginBottom: '1rem', color: 'var(--azure-blue)' }}>
            Job Status
          </h3>
          
          <div style={{ display: 'grid', gap: '0.5rem', marginBottom: '1rem' }}>
            <div>
              <strong>Job ID:</strong> <code>{jobStatus.job_id}</code>
            </div>
            <div>
              <strong>Status:</strong>{' '}
              <span
                style={{
                  padding: '0.25rem 0.75rem',
                  borderRadius: '12px',
                  background:
                    jobStatus.status === 'completed'
                      ? 'var(--success)'
                      : jobStatus.status === 'queued'
                      ? 'var(--warning)'
                      : 'var(--azure-blue)',
                  color: 'white',
                  fontSize: '0.875rem',
                  fontWeight: 600,
                }}
              >
                {jobStatus.status}
              </span>
            </div>
            <div>
              <strong>Total Files:</strong> {jobStatus.total_files}
            </div>
            {jobStatus.processed_files !== undefined && (
              <div>
                <strong>Processed:</strong>{' '}
                <span style={{ color: 'var(--success)' }}>{jobStatus.processed_files}</span>
                {jobStatus.failed_files !== undefined && jobStatus.failed_files > 0 && (
                  <span style={{ color: 'var(--error)', marginLeft: '0.5rem' }}>
                    ({jobStatus.failed_files} failed)
                  </span>
                )}
              </div>
            )}
            {jobStatus.source_container && (
              <div>
                <strong>Source:</strong> {jobStatus.source_container}
              </div>
            )}
            {jobStatus.target_container && (
              <div>
                <strong>Target:</strong> {jobStatus.target_container}
              </div>
            )}
          </div>

          {jobStatus.status === 'completed' && (
            <div
              style={{
                marginTop: '1rem',
                padding: '1rem',
                background: '#d4edda',
                color: '#155724',
                borderRadius: 'var(--border-radius)',
              }}
            >
              <div style={{ marginBottom: '0.5rem' }}>
                <strong>✅ Batch translation completed!</strong>
              </div>
              <div style={{ fontSize: '0.875rem' }}>
                📁 Translations saved in:
                <ul style={{ marginTop: '0.5rem', marginBottom: '0.5rem' }}>
                  <li><strong>NMT:</strong> {jobStatus.target_container}/nmt/</li>
                  <li><strong>LLM:</strong> {jobStatus.target_container}/llm/</li>
                </ul>
                Go to the "📊 Review" tab to view and rate translations.
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  )
}

