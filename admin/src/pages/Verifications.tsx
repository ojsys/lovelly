import { useCallback, useEffect, useState } from 'react'
import { api, when, type VerificationRow } from '../api'

export default function Verifications() {
  const [rows, setRows] = useState<VerificationRow[] | null>(null)
  const [error, setError] = useState<string | null>(null)
  const load = useCallback(
    () => api<{ results: VerificationRow[] }>('verifications').then((d) => setRows(d.results)).catch((e: Error) => setError(e.message)),
    [],
  )
  useEffect(() => {
    load()
  }, [load])

  async function decide(id: string, approve: boolean) {
    await api(`verifications/${id}`, { body: { approve } })
    await load()
  }

  return (
    <section className="stack">
      <h2>Selfie reviews</h2>
      {error && <p role="alert" className="danger">{error}</p>}
      {rows === null ? (
        <p className="muted">Loading…</p>
      ) : rows.length === 0 ? (
        <p className="muted">No selfies waiting.</p>
      ) : (
        rows.map((v) => (
          <div key={v.id} className="card stack">
            <p>
              <strong>{v.user.first_name}</strong>
              {v.user.age !== null && `, ${v.user.age}`} ·{' '}
              {v.reason === 'age_estimate' ? `looks under 18 (est. ${v.estimated_age})` : '3 failed selfie checks'} ·{' '}
              {when(v.created_at)}
            </p>
            <div className="frames">
              {v.images.map((src) => <img key={src} src={src} alt="Selfie pose" />)}
            </div>
            <div className="row">
              <button className="primary" onClick={() => decide(v.id, true)}>Approve</button>
              <button className="danger-button" onClick={() => decide(v.id, false)}>Reject</button>
            </div>
          </div>
        ))
      )}
    </section>
  )
}
