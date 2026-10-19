/// <reference types="vitest/config" />
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// The moderator console talks to Django through /api (and /admin-api from M4).
const apiTarget = process.env.VITE_API_PROXY ?? 'http://localhost:8100'

export default defineConfig({
  plugins: [react()],
  server: {
    proxy: {
      '/api': apiTarget,
      '/admin-api': apiTarget,
    },
  },
  test: {
    environment: 'jsdom',
    setupFiles: ['./src/setupTests.ts'],
  },
})
