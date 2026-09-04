import { useState } from 'react'
import type { FormEvent } from 'react'
import { supabase } from '../../lib/supabase'

type DemoAccount = {
  label: string
  email: string
}

function readDemoAccounts(): DemoAccount[] {
  const raw = import.meta.env.VITE_HOMETECHVN_DEMO_ACCOUNTS?.trim()
  if (!raw) return []

  return raw
    .split(',')
    .map((entry) => entry.trim())
    .filter(Boolean)
    .map((entry) => {
      const separator = entry.indexOf('|')
      if (separator < 1) return null
      const label = entry.slice(0, separator).trim()
      const email = entry.slice(separator + 1).trim()
      if (!label || !email) return null
      return { label, email }
    })
    .filter((entry): entry is DemoAccount => entry !== null)
}

export function LoginPage() {
  const demoMode = import.meta.env.VITE_HOMETECHVN_DEMO_MODE === 'true'
  const demoAccounts = demoMode ? readDemoAccounts() : []
  const demoPassword = demoMode ? import.meta.env.VITE_HOMETECHVN_DEMO_PASSWORD?.trim() ?? '' : ''
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setError(null)
    setBusy(true)

    try {
      const { error: signInError } = await supabase.auth.signInWithPassword({
        email: email.trim(),
        password,
      })
      if (signInError) throw signInError
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Đăng nhập thất bại.')
    } finally {
      setBusy(false)
    }
  }

  return (
    <main className="min-h-screen bg-slate-950 px-4 py-10 text-slate-100">
      <div className="mx-auto mt-12 max-w-md rounded-3xl border border-slate-800 bg-slate-900/90 p-8 shadow-2xl">
        <div className="mb-8">
          <p className="text-sm font-semibold uppercase tracking-[0.28em] text-cyan-400">
            HomeTechVN
          </p>
          <h1 className="mt-3 text-3xl font-bold">Đăng nhập hệ thống</h1>
          <p className="mt-2 text-sm text-slate-400">
            T17 — Demo tích hợp toàn hệ thống
          </p>
        </div>

        {demoMode && demoAccounts.length > 0 && demoPassword ? (
          <section className="mb-6 rounded-2xl border border-amber-800/70 bg-amber-950/25 p-4">
            <div className="text-sm font-semibold text-amber-200">T17 Local Demo</div>
            <p className="mt-1 text-xs leading-5 text-amber-100/70">
              Dữ liệu giả lập cục bộ. Chọn role để tự điền tài khoản; mật khẩu demo dùng chung và không phải secret production.
            </p>
            <div className="mt-3 grid grid-cols-2 gap-2 sm:grid-cols-3">
              {demoAccounts.map(({ label, email: accountEmail }) => (
                <button
                  key={accountEmail}
                  type="button"
                  onClick={() => {
                    setEmail(accountEmail)
                    setPassword(demoPassword)
                  }}
                  className="rounded-xl border border-amber-900/80 px-3 py-2 text-xs font-medium text-amber-100 transition hover:border-amber-600 hover:bg-amber-900/25"
                >
                  {label}
                </button>
              ))}
            </div>
            <div className="mt-3 break-all rounded-xl bg-slate-950/60 px-3 py-2 text-[11px] text-slate-400">
              Password local demo: <span className="font-mono text-slate-300">{demoPassword}</span>
            </div>
          </section>
        ) : null}

        <form className="space-y-5" onSubmit={handleSubmit}>
          <label className="block text-sm font-medium">
            Email
            <input
              className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-4 py-3 outline-none transition focus:border-cyan-500"
              type="email"
              autoComplete="username"
              value={email}
              onChange={(event) => setEmail(event.target.value)}
              required
            />
          </label>

          <label className="block text-sm font-medium">
            Mật khẩu
            <input
              className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-4 py-3 outline-none transition focus:border-cyan-500"
              type="password"
              autoComplete="current-password"
              value={password}
              onChange={(event) => setPassword(event.target.value)}
              required
            />
          </label>

          {error ? (
            <div className="rounded-xl border border-red-900/70 bg-red-950/50 px-4 py-3 text-sm text-red-200">
              {error}
            </div>
          ) : null}

          <button
            className="w-full rounded-xl bg-cyan-500 px-4 py-3 font-semibold text-slate-950 transition hover:bg-cyan-400 disabled:cursor-not-allowed disabled:opacity-60"
            type="submit"
            disabled={busy}
          >
            {busy ? 'Đang đăng nhập…' : 'Đăng nhập'}
          </button>
        </form>
      </div>
    </main>
  )
}
