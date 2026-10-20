import { useEffect, useState } from 'react'
import { api, reasonLabel, when, type Reason, type ReportRow } from '../api'

type Filter = 'all' | 'automatic' | 'user'

export default function Queue({ onOpen }: { onOpen: (id: string) => void }) {
  const [rows, setRows] = useState<ReportRow[] | null>(null)
  const [counts, setCounts] = useState<Partial<Record<Reason, number>>>({})
  const [filter, setFilter] = useState<Filter>('all')
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    const auto = filter === 'all' ? '' : `&automatic=${filter === 'automatic'}`
    api<{ results: ReportRow[]; open_by_reason: Partial<Record<Reason, number>> }>(`reports?status=open${auto}`)
      .then((data) => {
        setRows(data.results)
        setCounts(data.open_by_reason)
      })
      .catch((e: Error) => setError(e.message))
  }, [filter])

  return (
    <section className="stack">
      <header className="row between">
        <h2>Report queue</h2>
        <div className="row" role="group" aria-label="Source">
          {(['all', 'automatic', 'user'] as Filter[]).map((f) => (
            <button key={f} aria-pressed={filter === f} onClick={() => setFilter(f)}>
              {f === 'all' ? 'All' : f === 'automatic' ? 'Automatic' : 'From users'}
            </button>
          ))}
        </div>
      </header>
      <p className="muted">
        {(Object.keys(reasonLabel) as Reason[])
          .filter((r) => counts[r])
          .map((r) => `${reasonLabel[r]}: ${counts[r]}`)
          .join(' · ') || 'Nothing open.'}
      </p>
      {error && <p role="alert" className="danger">{error}</p>}
      {rows === null ? (
        <p className="muted">Loading…</p>
      ) : (
        <table>
          <thead>
            <tr>
              <th>Severity</th>
              <th>Reason</th>
              <th>Reported</th>
              <th>Source</th>
              <th>When</th>
              <th>Status</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((r) => (
              <tr key={r.id} onClick={() => onOpen(r.id)} className="clickable" tabIndex={0}
                  onKeyDown={(e) => e.key === 'Enter' && onOpen(r.id)}>
                <td><span className={`sev sev-${r.severity}`}>{r.severity}</span></td>
                <td>{reasonLabel[r.reason]}</td>
                <td>{r.reported.first_name}</td>
                <td>{r.automatic ? 'Automatic' : 'User'}{r.mode ? ` · ${r.mode}` : ''}</td>
                <td>{when(r.created_at)}</td>
                <td>{r.legal_hold ? 'Legal hold' : r.status}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </section>
  )
}
