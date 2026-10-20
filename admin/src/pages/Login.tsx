import { useState, type FormEvent } from 'react'
import { api, ApiError, session } from '../api'

export default function Login({ onDone }: { onDone: () => void }) {
  const [phone, setPhone] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)

  async function submit(e: FormEvent) {
    e.preventDefault()
    setBusy(true)
    setError(null)
    try {
      const tokens = await api<{ access: string }>('auth/login', { body: { phone, password } })
      session.set(tokens.access)
      onDone()
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Can’t reach the server.')
    } finally {
      setBusy(false)
    }
  }

  return (
    <main className="login">
      <h1>Korram moderation</h1>
      <form onSubmit={submit} className="card stack">
        <label>
          Phone
          <input value={phone} onChange={(e) => setPhone(e.target.value)} autoComplete="username" required />
        </label>
        <label>
          Password
          <input
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            autoComplete="current-password"
            required
          />
        </label>
        {error && <p role="alert" className="danger">{error}</p>}
        <button className="primary" disabled={busy}>
          {busy ? 'Signing in…' : 'Sign in'}
        </button>
      </form>
    </main>
  )
}
