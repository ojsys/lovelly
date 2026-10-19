import { useEffect, useState } from 'react'

type Health = { status: string; db: boolean; redis: boolean }

type State =
  | { kind: 'loading' }
  | { kind: 'ok'; health: Health }
  | { kind: 'error'; message: string }

export default function App() {
  const [state, setState] = useState<State>({ kind: 'loading' })

  useEffect(() => {
    fetch('/api/v1/health')
      .then(async (res) => {
        const health = (await res.json()) as Health
        setState({ kind: 'ok', health })
      })
      .catch((err: Error) => setState({ kind: 'error', message: err.message }))
  }, [])

  return (
    <main style={{ maxWidth: 560, margin: '64px auto', padding: '0 16px' }}>
      <h1 style={{ fontSize: 24 }}>Korram moderation</h1>
      <p style={{ color: 'var(--muted)' }}>The report queue arrives in M4.</p>
      <section
        aria-label="API health"
        style={{
          background: 'var(--surface)',
          border: '1px solid var(--line)',
          borderRadius: 16,
          padding: 16,
        }}
      >
        {state.kind === 'loading' && <p>Checking API…</p>}
        {state.kind === 'error' && (
          <p style={{ color: 'var(--danger)' }}>API unreachable: {state.message}</p>
        )}
        {state.kind === 'ok' && (
          <p style={{ color: state.health.status === 'ok' ? 'var(--mint)' : 'var(--danger)' }}>
            API {state.health.status} · database {state.health.db ? 'up' : 'down'} · redis{' '}
            {state.health.redis ? 'up' : 'down'}
          </p>
        )}
      </section>
    </main>
  )
}
