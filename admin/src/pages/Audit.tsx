import { useEffect, useState } from 'react'
import { api, when, type AuditRow } from '../api'

export default function Audit() {
  const [rows, setRows] = useState<AuditRow[] | null>(null)
  useEffect(() => {
    api<{ results: AuditRow[] }>('audit').then((d) => setRows(d.results)).catch(() => setRows([]))
  }, [])
  return (
    <section className="stack">
      <h2>Audit log</h2>
      <p className="muted">Every moderator and automatic action. Entries can’t be edited or deleted.</p>
      <table>
        <thead>
          <tr><th>When</th><th>Action</th><th>Person</th><th>By</th><th>Note</th></tr>
        </thead>
        <tbody>
          {(rows ?? []).map((a) => (
            <tr key={a.id}>
              <td>{when(a.at)}</td>
              <td>{a.action}</td>
              <td>{a.target}</td>
              <td>{a.moderator}</td>
              <td>{a.note}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </section>
  )
}
