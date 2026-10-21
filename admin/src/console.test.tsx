import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react'
import { afterEach, beforeEach, expect, test, vi } from 'vitest'
import App from './App'
import ReportDetail from './pages/ReportDetail'

type Handler = (body: unknown, method: string) => [number, unknown]
let routes: Record<string, Handler>
const calls: { path: string; method: string; body: unknown }[] = []

beforeEach(() => {
  calls.length = 0
  sessionStorage.clear()
  routes = {}
  vi.stubGlobal(
    'fetch',
    vi.fn(async (url: string, init: RequestInit) => {
      const path = url.replace('/admin-api/', '')
      const body = init.body ? JSON.parse(init.body as string) : undefined
      calls.push({ path, method: init.method ?? 'GET', body })
      const key = Object.keys(routes).find((k) => path.startsWith(k))
      const [status, data] = key ? routes[key](body, init.method ?? 'GET') : [404, { code: 'not_found', detail: 'nope' }]
      return { ok: status < 400, status, json: async () => data } as Response
    }),
  )
})
afterEach(() => {
  cleanup()
  vi.restoreAllMocks()
  vi.unstubAllGlobals()
})

const summary = (name: string) => ({
  id: name, first_name: name, age: 24, city: 'Abuja', verified: true, status: 'active',
  suspended_until: null, risk_score: 2, joined: '2026-10-01T10:00:00Z', reports_received: 1, actions: [],
})

const row = (id: string, reason: string, severity: number) => ({
  id, reason, severity, status: 'open', automatic: reason === 'nudity', legal_hold: false,
  created_at: '2026-10-20T10:00:00Z', reported: { id: 'u', first_name: 'Tobi' }, mode: 'video', session_id: 's',
})

test('login refuses non-moderators and signs moderators in', async () => {
  routes['auth/login'] = (body) =>
    (body as { password: string }).password === 'good'
      ? [200, { access: 'tok' }]
      : [401, { code: 'not_moderator', detail: 'Wrong phone or password, or not a moderator.' }]
  routes['reports'] = () => [200, { results: [], open_by_reason: {} }]
  render(<App />)
  fireEvent.change(screen.getByLabelText('Phone'), { target: { value: '+234' } })
  fireEvent.change(screen.getByLabelText('Password'), { target: { value: 'bad' } })
  fireEvent.click(screen.getByText('Sign in'))
  expect(await screen.findByRole('alert')).toHaveTextContent('not a moderator')
  fireEvent.change(screen.getByLabelText('Password'), { target: { value: 'good' } })
  fireEvent.click(screen.getByText('Sign in'))
  expect(await screen.findByText('Report queue')).toBeInTheDocument()
  expect(sessionStorage.getItem('lovelly.console.token')).toBe('tok')
})

test('SF-6: queue shows reports in the server’s severity order with counts', async () => {
  sessionStorage.setItem('lovelly.console.token', 'tok')
  routes['reports'] = () => [
    200,
    { results: [row('1', 'minor', 5), row('2', 'nudity', 4), row('3', 'scam', 2)], open_by_reason: { minor: 1, nudity: 1, scam: 1 } },
  ]
  render(<App />)
  const cells = await screen.findAllByRole('row')
  expect(cells[1]).toHaveTextContent('May be under 18')
  expect(cells[2]).toHaveTextContent('Nudity / sexual')
  expect(screen.getByText(/May be under 18: 1 · Nudity \/ sexual: 1/)).toBeInTheDocument()
  fireEvent.click(screen.getByText('Automatic'))
  await waitFor(() => expect(calls.at(-1)?.path).toBe('reports?status=open&automatic=true'))
})

const detail = {
  ...row('9', 'nudity', 4),
  referral: {},
  closed_at: null,
  session: { mode: 'video', started_at: '2026-10-20T10:00:00Z', ended_at: '2026-10-20T10:01:00Z', end_reason: 'moderation' },
  reported: summary('Tobi'),
  reporter: null,
  evidence: {
    frames: [{ role: 'reported', at: 1792509346, url: 'https://minio/x.jpg?sig' }],
    transcript: [{ sender: 'reported', body: 'hi', sent_at: '2026-10-20T10:00:10Z', flagged: false }],
  },
  history: [{ action: 'auto_block', at: '2026-10-20T10:01:00Z', note: 'nudity 0.99', moderator: 'automatic' }],
}

test('report detail shows evidence, both people and history', async () => {
  routes['reports/9'] = () => [200, detail]
  render(<ReportDetail id="9" onBack={() => {}} />)
  expect(await screen.findByRole('img')).toHaveAttribute('src', 'https://minio/x.jpg?sig')
  expect(screen.getByLabelText('Chat transcript')).toHaveTextContent('hi')
  expect(screen.getByText('Automatic report')).toBeInTheDocument()
  expect(screen.getByText(/auto_block by automatic/)).toBeInTheDocument()
})

test('actions post with the note; ban asks first', async () => {
  routes['reports/9/actions'] = () => [201, { id: 'a', action: 'warn' }]
  routes['reports/9'] = () => [200, detail]
  const confirm = vi.spyOn(window, 'confirm').mockReturnValue(false)
  render(<ReportDetail id="9" onBack={() => {}} />)
  await screen.findByRole('img')
  fireEvent.change(screen.getByLabelText(/Note/), { target: { value: 'Be kind' } })
  fireEvent.click(screen.getByText('Warn'))
  await waitFor(() => expect(calls.some((c) => c.path === 'reports/9/actions')).toBe(true))
  expect(calls.find((c) => c.path === 'reports/9/actions')?.body).toEqual({ action: 'warn', note: 'Be kind' })
  fireEvent.click(screen.getByText('Ban (phone + device)'))
  expect(confirm).toHaveBeenCalled()
  expect(calls.filter((c) => c.path === 'reports/9/actions')).toHaveLength(1) // cancelled
})

test('SF-9: legal hold then referral', async () => {
  let held = false
  routes['reports/9/actions'] = (body) => {
    if ((body as { action: string }).action === 'legal_hold') held = true
    return [201, {}]
  }
  routes['reports/9'] = () => [200, { ...detail, legal_hold: held }]
  vi.spyOn(window, 'confirm').mockReturnValue(true)
  render(<ReportDetail id="9" onBack={() => {}} />)
  await screen.findByRole('img')
  fireEvent.click(screen.getByText('Put on legal hold'))
  fireEvent.change(await screen.findByLabelText('Agency'), { target: { value: 'NAPTIP' } })
  fireEvent.change(screen.getByLabelText('Reference'), { target: { value: 'REF-1' } })
  fireEvent.click(screen.getByText('Record referral'))
  await waitFor(() =>
    expect(calls.find((c) => (c.body as { action?: string })?.action === 'referral')?.body).toMatchObject({
      referral: { agency: 'NAPTIP', reference: 'REF-1' },
    }),
  )
})
