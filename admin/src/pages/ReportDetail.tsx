import { useCallback, useEffect, useState } from 'react'
import { api, reasonLabel, when, type ReportDetail as Detail, type UserSummary } from '../api'

const ACTIONS: { action: string; label: string; danger?: boolean; confirm?: string }[] = [
  { action: 'warn', label: 'Warn' },
  { action: 'suspend_24h', label: 'Suspend 24 h' },
  { action: 'suspend_7d', label: 'Suspend 7 days' },
  { action: 'ban', label: 'Ban (phone + device)', danger: true, confirm: 'Ban this person permanently?' },
  { action: 'dismiss', label: 'Dismiss' },
  { action: 'escalate', label: 'Escalate' },
]

function Person({ title, user }: { title: string; user: UserSummary | null }) {
  if (!user) return <div className="card"><h3>{title}</h3><p className="muted">Automatic report</p></div>
  return (
    <div className="card">
      <h3>{title}</h3>
      <p>
        <strong>{user.first_name}</strong>
        {user.age !== null && `, ${user.age}`} {user.city && `· ${user.city}`} {user.verified && '· verified'}
      </p>
      <p className="muted">
        Status {user.status}
        {user.suspended_until && ` until ${when(user.suspended_until)}`} · risk {user.risk_score} ·{' '}
        {user.reports_received} reports · joined {when(user.joined)}
      </p>
      {user.actions.length > 0 && (
        <ul>
          {user.actions.map((a, i) => (
            <li key={i}>{a.action} · {when(a.at)}{a.note && ` · ${a.note}`}</li>
          ))}
        </ul>
      )}
    </div>
  )
}

export default function ReportDetail({ id, onBack }: { id: string; onBack: () => void }) {
  const [report, setReport] = useState<Detail | null>(null)
  const [note, setNote] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const [referral, setReferral] = useState({ agency: '', reference: '', date: '' })

  const load = useCallback(
    () => api<Detail>(`reports/${id}`).then(setReport).catch((e: Error) => setError(e.message)),
    [id],
  )
  useEffect(() => {
    load()
  }, [load])

  async function act(action: string, extra: object = {}, confirmText?: string) {
    if (confirmText && !window.confirm(confirmText)) return
    setBusy(true)
    setError(null)
    try {
      await api(`reports/${id}/actions`, { body: { action, note, ...extra } })
      setNote('')
      await load()
    } catch (e) {
      setError((e as Error).message)
    } finally {
      setBusy(false)
    }
  }

  if (!report) return <p className="muted">{error ?? 'Loading…'}</p>
  const closed = report.status === 'actioned' || report.status === 'dismissed'

  return (
    <section className="stack">
      <button onClick={onBack}>← Queue</button>
      <header>
        <h2>
          {reasonLabel[report.reason]} <span className={`sev sev-${report.severity}`}>{report.severity}</span>
        </h2>
        <p className="muted">
          {report.automatic ? 'Automatic' : 'User'} report · {when(report.created_at)} · {report.status}
          {report.legal_hold && ' · LEGAL HOLD'}
          {report.session && ` · ${report.session.mode} session ended (${report.session.end_reason || 'live'})`}
        </p>
      </header>

      <div className="card">
        <h3>Evidence</h3>
        {report.evidence.frames.length === 0 ? (
          <p className="muted">No video frames (voice or text session).</p>
        ) : (
          <div className="frames" aria-label="Sampled frames">
            {report.evidence.frames.map((f) => (
              <figure key={f.url}>
                <img src={f.url} alt={`${f.role} at ${new Date(f.at * 1000).toLocaleTimeString()}`} />
                <figcaption>{f.role} · {new Date(f.at * 1000).toLocaleTimeString()}</figcaption>
              </figure>
            ))}
          </div>
        )}
        {report.evidence.transcript.length > 0 && (
          <ol className="transcript" aria-label="Chat transcript">
            {report.evidence.transcript.map((m, i) => (
              <li key={i} className={m.sender}>
                <span className="muted">{m.sender}</span> {m.body} {m.flagged && <em className="danger">flagged</em>}
              </li>
            ))}
          </ol>
        )}
      </div>

      <div className="grid2">
        <Person title="Reported" user={report.reported} />
        <Person title="Reporter" user={report.reporter} />
      </div>

      <div className="card stack">
        <h3>Action</h3>
        <label>
          Note (shown to the person for warnings)
          <textarea value={note} onChange={(e) => setNote(e.target.value)} rows={2} />
        </label>
        <div className="row wrap">
          {ACTIONS.map((a) => (
            <button
              key={a.action}
              className={a.danger ? 'danger-button' : undefined}
              disabled={busy || (closed && a.action !== 'escalate')}
              onClick={() => act(a.action, {}, a.confirm)}
            >
              {a.label}
            </button>
          ))}
        </div>
        <details>
          <summary>Suspected child sexual abuse material (SF-9)</summary>
          <div className="stack">
            {!report.legal_hold ? (
              <button
                className="danger-button"
                disabled={busy}
                onClick={() => act('legal_hold', {}, 'Put this report on permanent legal hold?')}
              >
                Put on legal hold
              </button>
            ) : (
              <>
                <p className="muted">On legal hold: evidence can’t be deleted.</p>
                <div className="row wrap">
                  <input aria-label="Agency" placeholder="Agency" value={referral.agency}
                         onChange={(e) => setReferral({ ...referral, agency: e.target.value })} />
                  <input aria-label="Reference" placeholder="Reference" value={referral.reference}
                         onChange={(e) => setReferral({ ...referral, reference: e.target.value })} />
                  <input aria-label="Date" type="date" value={referral.date}
                         onChange={(e) => setReferral({ ...referral, date: e.target.value })} />
                  <button disabled={busy} onClick={() => act('referral', { referral })}>Record referral</button>
                </div>
                {report.referral.reference && (
                  <p>Referred to {report.referral.agency} · {report.referral.reference} · {report.referral.date}</p>
                )}
              </>
            )}
          </div>
        </details>
        {error && <p role="alert" className="danger">{error}</p>}
      </div>

      <div className="card">
        <h3>History</h3>
        {report.history.length === 0 ? (
          <p className="muted">No actions yet.</p>
        ) : (
          <ul>
            {report.history.map((h, i) => (
              <li key={i}>{h.action} by {h.moderator} · {when(h.at)}{h.note && ` · ${h.note}`}</li>
            ))}
          </ul>
        )}
      </div>
    </section>
  )
}
