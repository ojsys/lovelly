import { render, screen } from '@testing-library/react'
import { afterEach, expect, test, vi } from 'vitest'
import App from './App'

afterEach(() => vi.unstubAllGlobals())

test('shows API health from /api/v1/health', async () => {
  vi.stubGlobal(
    'fetch',
    vi.fn().mockResolvedValue({ json: async () => ({ status: 'ok', db: true, redis: true }) }),
  )
  render(<App />)
  expect(await screen.findByText(/API ok · database up · redis up/)).toBeInTheDocument()
})

test('shows an error when the API is unreachable', async () => {
  vi.stubGlobal('fetch', vi.fn().mockRejectedValue(new Error('offline')))
  render(<App />)
  expect(await screen.findByText(/API unreachable: offline/)).toBeInTheDocument()
})
