import { useState } from 'react'
import { session } from './api'
import Audit from './pages/Audit'
import Login from './pages/Login'
import Queue from './pages/Queue'
import ReportDetail from './pages/ReportDetail'
import Verifications from './pages/Verifications'

type View = { page: 'queue' } | { page: 'report'; id: string } | { page: 'verifications' } | { page: 'audit' }

export default function App() {
  const [signedIn, setSignedIn] = useState(() => session.get() !== null)
  const [view, setView] = useState<View>({ page: 'queue' })

  if (!signedIn) return <Login onDone={() => setSignedIn(true)} />

  const tab = (page: 'queue' | 'verifications' | 'audit', label: string) => (
    <button aria-current={view.page === page || (page === 'queue' && view.page === 'report')}
            onClick={() => setView({ page })}>
      {label}
    </button>
  )

  return (
    <div className="shell">
      <nav className="row between">
        <strong>Korram moderation</strong>
        <div className="row">
          {tab('queue', 'Reports')}
          {tab('verifications', 'Selfie reviews')}
          {tab('audit', 'Audit log')}
          <button onClick={() => { session.clear(); setSignedIn(false) }}>Sign out</button>
        </div>
      </nav>
      <main>
        {view.page === 'queue' && <Queue onOpen={(id) => setView({ page: 'report', id })} />}
        {view.page === 'report' && <ReportDetail id={view.id} onBack={() => setView({ page: 'queue' })} />}
        {view.page === 'verifications' && <Verifications />}
        {view.page === 'audit' && <Audit />}
      </main>
    </div>
  )
}
