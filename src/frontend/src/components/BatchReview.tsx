import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useMutation, useQuery } from '@tanstack/react-query'
import translatorAPI from '../services/api'
import { trackEvent } from '../services/telemetry'

export default function BatchReview() {
  const { t } = useTranslation()
  const [selectedContainer, setSelectedContainer] = useState('')
  const [selectedFile, setSelectedFile] = useState<any>(null)
  const [fileContent, setFileContent] = useState<any>(null)
  const [sourceContainer, setSourceContainer] = useState('')
  const [targetContainer, setTargetContainer] = useState('')
  const [evaluationVotes, setEvaluationVotes] = useState<Record<string, 'nmt' | 'llm' | null>>({})

  // Fetch containers
  const { data: containersData, isLoading: containersLoading } = useQuery({
    queryKey: ['containers'],
    queryFn: () => translatorAPI.listContainers(),
  })

  // Fetch translated files from selected container
  const {
    data: filesData,
    isLoading: filesLoading,
    refetch: refetchFiles,
  } = useQuery({
    queryKey: ['translated-files', selectedContainer],
    queryFn: () => translatorAPI.listTranslatedFiles(selectedContainer),
    enabled: !!selectedContainer,
  })

  // Fetch file translations
  const loadFileMutation = useMutation({
    mutationFn: async (filename: string) => {
      return translatorAPI.getFileTranslations(selectedContainer, filename)
    },
    onSuccess: (data) => {
      setFileContent(data)
    },
  })

  // Submit rating mutation
  const submitRatingMutation = useMutation({
    mutationFn: async (data: { preferred: 'nmt' | 'llm'; comments?: string }) => {
      return translatorAPI.submitRating(
        fileContent.filename,
        selectedContainer,
        fileContent.nmt_blob,
        fileContent.llm_blob,
        data.preferred,
        data.comments
      )
    },
    onSuccess: (data) => {
      trackEvent('Rating_Submitted', {
        filename: fileContent.filename,
        preferred: data.preferred,
      })
      // Move to next file
      if (filesData && filesData.files) {
        const currentIndex = filesData.files.findIndex((f: any) => f.filename === fileContent.filename)
        if (currentIndex < filesData.files.length - 1) {
          const nextFile = filesData.files[currentIndex + 1]
          handleLoadFile(nextFile)
        } else {
          setFileContent(null)
          alert('All files rated! See statistics.')
        }
      }
    },
  })

  // Fetch evaluation data
  const { data: evaluationData, isLoading: evaluationLoading } = useQuery({
    queryKey: ['evaluation-data', sourceContainer, targetContainer],
    queryFn: () => translatorAPI.getEvaluationData(sourceContainer, targetContainer),
    enabled: !!sourceContainer && !!targetContainer,
  })

  const handleLoadFile = (file: any) => {
    setSelectedFile(file)
    loadFileMutation.mutate(file.filename)
  }

  const handleRating = (preferred: 'nmt' | 'llm') => {
    submitRatingMutation.mutate({ preferred })
  }

  const handleVote = (filename: string, choice: 'nmt' | 'llm') => {
    setEvaluationVotes(prev => ({
      ...prev,
      [filename]: prev[filename] === choice ? null : choice
    }))
  }

  const handleDownloadCSV = () => {
    if (!evaluationData || !evaluationData.files) return

    // Create CSV content
    const headers = ['Source_File_Name', 'NMT_Score', 'LLM_Score']
    const rows = evaluationData.files.map((file: any) => {
      const vote = evaluationVotes[file.filename]
      const nmtScore = vote === 'nmt' ? 1 : 0
      const llmScore = vote === 'llm' ? 1 : 0
      return [file.filename, nmtScore, llmScore]
    })

    const csvContent = [
      headers.join(','),
      ...rows.map((row: (string | number)[]) => row.join(','))
    ].join('\n')

    // Create download
    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' })
    const link = document.createElement('a')
    const url = URL.createObjectURL(blob)
    link.setAttribute('href', url)
    link.setAttribute('download', `translation_evaluation_${new Date().toISOString().split('T')[0]}.csv`)
    link.style.visibility = 'hidden'
    document.body.appendChild(link)
    link.click()
    document.body.removeChild(link)

    trackEvent('CSV_Downloaded', {
      total_files: evaluationData.files.length,
      voted_files: Object.keys(evaluationVotes).filter(k => evaluationVotes[k]).length
    })
  }

  return (
    <div className="batch-review">
      <div style={{ marginBottom: '1rem' }}>
        <h2 style={{ marginBottom: '0.5rem', color: 'var(--azure-blue)' }}>
          🔍 Evaluate Translations
        </h2>
        <p style={{ color: 'var(--gray-700)' }}>
          Compare source files with NMT and LLM translations side-by-side, vote for your preferred translation, and download results
        </p>
      </div>

      {/* Container Selection - Always Visible */}
      <div style={{ marginBottom: '2rem' }}>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
          <div>
            <label htmlFor="eval-source">Source Container</label>
            <select
              id="eval-source"
              value={sourceContainer}
              onChange={(e) => setSourceContainer(e.target.value)}
              disabled={containersLoading}
              style={{
                width: '100%',
                padding: '0.75rem',
                border: '1px solid var(--gray-300)',
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
          </div>

          <div>
            <label htmlFor="eval-target">Translation Container</label>
            <select
              id="eval-target"
              value={targetContainer}
              onChange={(e) => setTargetContainer(e.target.value)}
              disabled={containersLoading}
              style={{
                width: '100%',
                padding: '0.75rem',
                border: '1px solid var(--gray-300)',
                borderRadius: 'var(--border-radius)',
              }}
            >
              <option value="">Select translation container...</option>
              {containersData?.containers.map((container: string) => (
                <option key={container} value={container}>
                  {container}
                </option>
              ))}
            </select>
          </div>
        </div>
      </div>

      {/* Evaluation View */}
      {evaluationLoading && (
        <div style={{ textAlign: 'center', padding: '2rem' }}>
          <div className="spinner" />
          <p>Loading evaluation data...</p>
        </div>
      )}

      {evaluationData && evaluationData.files && evaluationData.files.length > 0 && (
        <div style={{ marginBottom: '2rem' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1rem', padding: '1rem', background: 'var(--gray-100)', borderRadius: 'var(--border-radius)' }}>
            <div>
              <strong>📊 {evaluationData.total} file(s) ready for evaluation</strong>
              <div style={{ fontSize: '0.875rem', color: 'var(--gray-600)', marginTop: '0.25rem' }}>
                {Object.values(evaluationVotes).filter(v => v).length} voted
              </div>
            </div>
            <button
              onClick={handleDownloadCSV}
              style={{
                padding: '0.75rem 1.5rem',
                background: 'var(--azure-blue)',
                color: 'white',
                border: 'none',
                borderRadius: 'var(--border-radius)',
                cursor: 'pointer',
                fontWeight: 600,
              }}
            >
              📥 Download CSV
            </button>
          </div>

          {/* 3-Pane Layout */}
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: '1rem', marginBottom: '2rem' }}>
            {/* Source Column Header */}
            <div style={{ padding: '1rem', background: 'var(--gray-100)', borderRadius: 'var(--border-radius)', fontWeight: 600, textAlign: 'center' }}>
              📄 Source Files
            </div>
            {/* NMT Column Header */}
            <div style={{ padding: '1rem', background: '#e3f2fd', borderRadius: 'var(--border-radius)', fontWeight: 600, textAlign: 'center' }}>
              🤖 NMT Translation
            </div>
            {/* LLM Column Header */}
            <div style={{ padding: '1rem', background: '#f3e5f5', borderRadius: 'var(--border-radius)', fontWeight: 600, textAlign: 'center' }}>
              🧠 LLM Translation
            </div>
          </div>

          {/* File Rows */}
          {evaluationData.files.map((file: any, index: number) => (
            <div key={file.filename} style={{ marginBottom: '2rem' }}>
              <div style={{ marginBottom: '0.5rem', padding: '0.5rem', background: 'var(--gray-100)', borderRadius: 'var(--border-radius)', fontWeight: 600 }}>
                📄 {file.filename}
              </div>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: '1rem' }}>
                {/* Source Content */}
                <div style={{
                  padding: '1rem',
                  background: 'white',
                  border: '2px solid var(--gray-300)',
                  borderRadius: 'var(--border-radius)',
                  minHeight: '150px',
                  maxHeight: '300px',
                  overflowY: 'auto',
                  fontSize: '0.9rem',
                  lineHeight: '1.6',
                  whiteSpace: 'pre-wrap',
                }}>
                  {file.source_content}
                </div>

                {/* NMT Translation */}
                <div>
                  <div style={{
                    padding: '1rem',
                    background: 'white',
                    border: evaluationVotes[file.filename] === 'nmt' ? '3px solid #2196f3' : '2px solid #2196f3',
                    borderRadius: 'var(--border-radius)',
                    minHeight: '150px',
                    maxHeight: '300px',
                    overflowY: 'auto',
                    fontSize: '0.9rem',
                    lineHeight: '1.6',
                    whiteSpace: 'pre-wrap',
                    marginBottom: '0.5rem',
                  }}>
                    {file.nmt_content}
                  </div>
                  <button
                    onClick={() => handleVote(file.filename, 'nmt')}
                    style={{
                      width: '100%',
                      padding: '0.5rem',
                      background: evaluationVotes[file.filename] === 'nmt' ? '#2196f3' : 'white',
                      color: evaluationVotes[file.filename] === 'nmt' ? 'white' : '#2196f3',
                      border: '2px solid #2196f3',
                      borderRadius: 'var(--border-radius)',
                      cursor: 'pointer',
                      fontWeight: 600,
                      fontSize: '0.875rem',
                    }}
                  >
                    {evaluationVotes[file.filename] === 'nmt' ? '✓ Selected' : 'Select NMT'}
                  </button>
                </div>

                {/* LLM Translation */}
                <div>
                  <div style={{
                    padding: '1rem',
                    background: 'white',
                    border: evaluationVotes[file.filename] === 'llm' ? '3px solid #9c27b0' : '2px solid #9c27b0',
                    borderRadius: 'var(--border-radius)',
                    minHeight: '150px',
                    maxHeight: '300px',
                    overflowY: 'auto',
                    fontSize: '0.9rem',
                    lineHeight: '1.6',
                    whiteSpace: 'pre-wrap',
                    marginBottom: '0.5rem',
                  }}>
                    {file.llm_content}
                  </div>
                  <button
                    onClick={() => handleVote(file.filename, 'llm')}
                    style={{
                      width: '100%',
                      padding: '0.5rem',
                      background: evaluationVotes[file.filename] === 'llm' ? '#9c27b0' : 'white',
                      color: evaluationVotes[file.filename] === 'llm' ? 'white' : '#9c27b0',
                      border: '2px solid #9c27b0',
                      borderRadius: 'var(--border-radius)',
                      cursor: 'pointer',
                      fontWeight: 600,
                      fontSize: '0.875rem',
                    }}
                  >
                    {evaluationVotes[file.filename] === 'llm' ? '✓ Selected' : 'Select LLM'}
                  </button>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      {evaluationData && evaluationData.files && evaluationData.files.length === 0 && (
        <div style={{ textAlign: 'center', padding: '2rem', color: 'var(--gray-600)' }}>
          <p>No translated files found. Run a batch translation first.</p>
        </div>
      )}

      {!sourceContainer && !targetContainer && (
        <div style={{ textAlign: 'center', padding: '3rem', color: 'var(--gray-600)' }}>
          <div style={{ fontSize: '3rem', marginBottom: '1rem' }}>🔍</div>
          <h3 style={{ marginBottom: '0.5rem' }}>Select Containers to Begin</h3>
          <p>Choose a source container and translation container above to evaluate translations.</p>
        </div>
      )}
    </div>
  )
}

