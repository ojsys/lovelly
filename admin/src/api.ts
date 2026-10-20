// Moderator console API client (/admin-api/, SF-6). Token lives for the browser tab only.

const TOKEN = 'korram.console.token'

export class ApiError extends Error {
  status: number
  code: string
  constructor(status: number, code: string, detail: string) {
    super(detail)
    this.status = status
    this.code = code
  }
}

export const session = {
  get: () => sessionStorage.getItem(TOKEN),
  set: (token: string) => sessionStorage.setItem(TOKEN, token),
  clear: () => sessionStorage.removeItem(TOKEN),
}

export async function api<T>(path: string, init: { method?: string; body?: unknown } = {}): Promise<T> {
  const token = session.get()
  const res = await fetch(`/admin-api/${path}`, {
    method: init.method ?? (init.body ? 'POST' : 'GET'),
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: init.body ? JSON.stringify(init.body) : undefined,
  })
  const data = res.status === 204 ? null : await res.json().catch(() => null)
  if (!res.ok) {
    if (res.status === 401) session.clear()
    throw new ApiError(res.status, data?.code ?? 'error', data?.detail ?? `Request failed (${res.status})`)
  }
  return data as T
}

export type Reason = 'minor' | 'nudity' | 'harassment' | 'scam' | 'fake' | 'other'

export const reasonLabel: Record<Reason, string> = {
  minor: 'May be under 18',
  nudity: 'Nudity / sexual',
  harassment: 'Harassment / hate',
  scam: 'Scam / money',
  fake: 'Fake profile',
  other: 'Something else',
}

export interface ReportRow {
  id: string
  reason: Reason
  severity: number
  status: 'open' | 'escalated' | 'actioned' | 'dismissed'
  automatic: boolean
  legal_hold: boolean
  created_at: string
  reported: { id: string; first_name: string }
  mode: string | null
  session_id: string | null
}

export interface UserSummary {
  id: string
  first_name: string
  age: number | null
  city: string
  verified: boolean
  status: string
  suspended_until: string | null
  risk_score: number
  joined: string
  reports_received: number
  actions: { action: string; at: string; note: string }[]
}

export interface ReportDetail extends ReportRow {
  referral: { agency?: string; reference?: string; date?: string }
  closed_at: string | null
  session: { mode: string; started_at: string; ended_at: string | null; end_reason: string } | null
  reported: UserSummary
  reporter: UserSummary | null
  evidence: {
    frames: { role: 'reported' | 'reporter'; at: number; url: string }[]
    transcript: { sender: 'reported' | 'reporter'; body: string; sent_at: string; flagged: boolean }[]
  }
  history: { action: string; at: string; note: string; moderator: string }[]
}

export interface VerificationRow {
  id: string
  reason: string
  estimated_age: number | null
  created_at: string
  user: UserSummary
  images: string[]
}

export interface AuditRow {
  id: string
  action: string
  at: string
  note: string
  duration: number | null
  moderator: string
  target: string
  report_id: string | null
}

export const when = (iso: string) =>
  new Date(iso).toLocaleString(undefined, { dateStyle: 'medium', timeStyle: 'short' })
