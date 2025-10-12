import { describe, it, expect } from 'vitest'
import { render, screen } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import App from '../../src/frontend/src/App'
import '../../src/frontend/src/i18n/config'

const createTestQueryClient = () =>
  new QueryClient({
    defaultOptions: {
      queries: {
        retry: false,
      },
    },
  })

describe('App', () => {
  it('renders the app title', () => {
    const queryClient = createTestQueryClient()
    render(
      <QueryClientProvider client={queryClient}>
        <App />
      </QueryClientProvider>
    )
    
    expect(screen.getByText(/Azure Translator/i)).toBeInTheDocument()
  })
})

