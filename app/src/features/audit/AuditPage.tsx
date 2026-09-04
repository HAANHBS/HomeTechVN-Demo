import { useCallback, useEffect, useMemo, useState, type FormEvent } from 'react'
import type { AppUserContext } from '../../lib/permissions'
import { supabase } from '../../lib/supabase'

type AuditRow = {
  id: number
  occurred_at: string
  actor_user_id: string | null
  actor_name: string | null
  actor_email: string | null
  table_name: string
  record_id: string | null
  action: 'INSERT' | 'UPDATE' | 'DELETE'
  old_data: unknown
  new_data: unknown
}

type AuditResult = {
  generated_at: string
  start_at: string
  end_at: string
  limit: number
  rows: AuditRow[]
  next_before_id: number | null
}

type SecuritySnapshot = {
  generated_at: string
  audit: {
    rows: number
    last_event_at: string | null
    audited_tables: number
    append_only_guards: number
    trigger_search_path: string
  }
  rls: {
    enabled_tables: number
    tables_without_policy: number
  }
  sequence_counters: {
    deny_policy: boolean
    service_role_direct_table_privilege: boolean
  }
}

function localIsoDate(date: Date) {
  const y = date.getFullYear()
  const m = String(date.getMonth() + 1).padStart(2, '0')
  const d = String(date.getDate()).padStart(2, '0')
  return `${y}-${m}-${d}`
}

function defaultRange() {
  const end = new Date()
  const start = new Date()
  start.setDate(end.getDate() - 29)
  return { start: localIsoDate(start), end: localIsoDate(end) }
}

function asStart(value: string) {
  return new Date(`${value}T00:00:00`).toISOString()
}

function asEnd(value: string) {
  return new Date(`${value}T23:59:59.999`).toISOString()
}

function dateTime(value: string | null | undefined) {
  return value ? new Date(value).toLocaleString('vi-VN') : '—'
}

function statusTone(ok: boolean) {
  return ok
    ? 'border-emerald-900/70 bg-emerald-950/20 text-emerald-300'
    : 'border-red-900/70 bg-red-950/25 text-red-300'
}

function JsonView({ label, value }: { label: string; value: unknown }) {
  if (value === null || value === undefined) {
    return (
      <div>
        <div className="mb-2 text-xs font-semibold uppercase tracking-[0.12em] text-slate-500">{label}</div>
        <div className="rounded-xl border border-slate-800 bg-slate-950 p-3 text-sm text-slate-500">Không có dữ liệu.</div>
      </div>
    )
  }

  return (
    <div>
      <div className="mb-2 text-xs font-semibold uppercase tracking-[0.12em] text-slate-500">{label}</div>
      <pre className="max-h-[46vh] overflow-auto whitespace-pre-wrap break-words rounded-xl border border-slate-800 bg-slate-950 p-3 text-xs leading-5 text-slate-300">
        {JSON.stringify(value, null, 2)}
      </pre>
    </div>
  )
}

export function AuditPage({ context }: { context: AppUserContext }) {
  const initial = useMemo(defaultRange, [])
  const [startDate, setStartDate] = useState(initial.start)
  const [endDate, setEndDate] = useState(initial.end)
  const [tableName, setTableName] = useState('')
  const [action, setAction] = useState('')
  const [recordId, setRecordId] = useState('')
  const [result, setResult] = useState<AuditResult | null>(null)
  const [snapshot, setSnapshot] = useState<SecuritySnapshot | null>(null)
  const [selected, setSelected] = useState<AuditRow | null>(null)
  const [loading, setLoading] = useState(false)
  const [snapshotLoading, setSnapshotLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const loadSnapshot = useCallback(async () => {
    setSnapshotLoading(true)
    try {
      const { data, error: rpcError } = await supabase.rpc('security_audit_snapshot')
      if (rpcError) throw rpcError
      setSnapshot(data as unknown as SecuritySnapshot)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Không tải được security snapshot.')
    } finally {
      setSnapshotLoading(false)
    }
  }, [])

  const load = useCallback(async (beforeId: number | null = null, append = false) => {
    setLoading(true)
    setError(null)
    try {
      const { data, error: rpcError } = await supabase.rpc('audit_search', {
        p_start_at: asStart(startDate),
        p_end_at: asEnd(endDate),
        p_table_name: tableName.trim() || null,
        p_action: action || null,
        p_actor_user_id: null,
        p_record_id: recordId.trim() || null,
        p_before_id: beforeId,
        p_limit: 100,
      })
      if (rpcError) throw rpcError
      const next = data as unknown as AuditResult
      if (append && result) {
        setResult({
          ...next,
          rows: [...result.rows, ...next.rows],
        })
      } else {
        setResult(next)
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Không tải được Audit Log.')
    } finally {
      setLoading(false)
    }
  }, [action, endDate, recordId, result, startDate, tableName])

  useEffect(() => {
    void Promise.all([load(null, false), loadSnapshot()])
    // First load only; filters are submitted explicitly.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setSelected(null)
    void load(null, false)
  }

  const securityCards = snapshot ? [
    {
      label: 'Audit events',
      value: String(snapshot.audit.rows),
      note: `Mới nhất ${dateTime(snapshot.audit.last_event_at)}`,
      ok: snapshot.audit.rows >= 0,
    },
    {
      label: 'Bảng có audit',
      value: String(snapshot.audit.audited_tables),
      note: 'Trigger fn_audit_row',
      ok: snapshot.audit.audited_tables > 0,
    },
    {
      label: 'Append-only guards',
      value: `${snapshot.audit.append_only_guards}/2`,
      note: 'UPDATE/DELETE + TRUNCATE',
      ok: snapshot.audit.append_only_guards === 2,
    },
    {
      label: 'RLS thiếu policy',
      value: String(snapshot.rls.tables_without_policy),
      note: `${snapshot.rls.enabled_tables} bảng RLS`,
      ok: snapshot.rls.tables_without_policy === 0,
    },
    {
      label: 'Sequence deny policy',
      value: snapshot.sequence_counters.deny_policy ? 'PASS' : 'FAIL',
      note: 'private.sequence_counters',
      ok: snapshot.sequence_counters.deny_policy,
    },
    {
      label: 'Service-role direct access',
      value: snapshot.sequence_counters.service_role_direct_table_privilege ? 'CÓ' : 'KHÔNG',
      note: 'Sequence table',
      ok: !snapshot.sequence_counters.service_role_direct_table_privilege,
    },
  ] : []

  return (
    <main className="min-h-screen bg-slate-950 text-slate-200">
      <header className="sticky top-0 z-30 border-b border-slate-800/90 bg-slate-950/90 px-3 py-3 backdrop-blur-xl sm:px-6">
        <div className="mx-auto flex max-w-7xl flex-wrap items-center justify-between gap-3">
          <div>
            <div className="text-xs font-semibold uppercase tracking-[0.24em] text-cyan-400">HomeTechVN · T16</div>
            <h1 className="mt-1 text-lg font-bold text-white sm:text-xl">Bảo mật & Nhật ký Audit</h1>
          </div>
          <button
            type="button"
            onClick={() => void Promise.all([load(null, false), loadSnapshot()])}
            disabled={loading || snapshotLoading}
            className="rounded-xl border border-slate-700 px-3 py-2 text-sm hover:border-cyan-800 disabled:opacity-50"
          >
            Làm mới
          </button>
        </div>
      </header>

      <div className="mx-auto max-w-7xl space-y-5 px-3 py-5 pb-24 sm:px-6 lg:pb-8">
        <section className="rounded-3xl border border-slate-800 bg-slate-900/90 p-4 sm:p-5">
          <div className="mb-4">
            <h2 className="font-semibold text-white">Security posture</h2>
            <p className="mt-1 text-xs leading-5 text-slate-500">
              Snapshot chỉ gồm trạng thái database/audit, không đọc hoặc hiển thị secret.
            </p>
          </div>

          {snapshotLoading && !snapshot ? (
            <div className="py-8 text-center text-sm text-slate-500">Đang kiểm tra…</div>
          ) : (
            <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 xl:grid-cols-6">
              {securityCards.map((card) => (
                <article key={card.label} className={`min-w-0 rounded-2xl border p-4 ${statusTone(card.ok)}`}>
                  <div className="text-[11px] font-semibold uppercase tracking-[0.1em] text-slate-400">{card.label}</div>
                  <div className="mt-2 break-words text-xl font-bold text-white">{card.value}</div>
                  <div className="mt-2 text-xs leading-5 text-slate-500">{card.note}</div>
                </article>
              ))}
            </div>
          )}

          <div className="mt-4 rounded-xl border border-amber-900/60 bg-amber-950/20 p-3 text-xs leading-5 text-amber-100">
            Leaked Password Protection của Supabase không nằm trong snapshot SQL. Project hiện dùng Free plan; T16 ghi nhận đây là giới hạn gói, không giả lập PASS bằng code.
          </div>
        </section>

        <form onSubmit={submit} className="rounded-3xl border border-slate-800 bg-slate-900/90 p-4 sm:p-5">
          <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-5">
            <label className="text-sm font-medium">
              Từ ngày
              <input
                type="date"
                required
                value={startDate}
                onChange={(event) => setStartDate(event.target.value)}
                className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2"
              />
            </label>

            <label className="text-sm font-medium">
              Đến ngày
              <input
                type="date"
                required
                value={endDate}
                onChange={(event) => setEndDate(event.target.value)}
                className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2"
              />
            </label>

            <label className="text-sm font-medium">
              Bảng
              <input
                value={tableName}
                onChange={(event) => setTableName(event.target.value)}
                placeholder="VD: sales_orders"
                className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2"
              />
            </label>

            <label className="text-sm font-medium">
              Hành động
              <select
                value={action}
                onChange={(event) => setAction(event.target.value)}
                className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2"
              >
                <option value="">Tất cả</option>
                <option value="INSERT">INSERT</option>
                <option value="UPDATE">UPDATE</option>
                <option value="DELETE">DELETE</option>
              </select>
            </label>

            <label className="text-sm font-medium">
              Record ID
              <input
                value={recordId}
                onChange={(event) => setRecordId(event.target.value)}
                placeholder="UUID / key"
                className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2"
              />
            </label>
          </div>

          <div className="mt-4 flex flex-wrap gap-2">
            <button
              disabled={loading}
              className="rounded-xl bg-cyan-500 px-4 py-2 text-sm font-semibold text-slate-950 disabled:opacity-50"
            >
              {loading ? 'Đang tải…' : 'Lọc audit'}
            </button>
            <button
              type="button"
              onClick={() => {
                const range = defaultRange()
                setStartDate(range.start)
                setEndDate(range.end)
                setTableName('')
                setAction('')
                setRecordId('')
              }}
              className="rounded-xl border border-slate-700 px-4 py-2 text-sm"
            >
              Xóa bộ lọc
            </button>
          </div>
        </form>

        {error ? (
          <div className="rounded-2xl border border-red-900/70 bg-red-950/30 p-4 text-sm text-red-200">{error}</div>
        ) : null}

        <section className="rounded-3xl border border-slate-800 bg-slate-900/90 p-4 sm:p-5">
          <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
            <div>
              <h2 className="font-semibold text-white">Audit events</h2>
              <p className="mt-1 text-xs text-slate-500">
                {result ? `${result.rows.length} dòng đang hiển thị · tối đa 200 dòng mỗi request` : 'Chưa có dữ liệu'}
              </p>
            </div>
            <div className="text-xs text-slate-500">Người xem: {context.fullName || context.email || context.roleName}</div>
          </div>

          <div className="overflow-x-auto">
            <table className="w-full min-w-[1000px] text-left text-sm">
              <thead className="text-xs uppercase text-slate-500">
                <tr>
                  <th className="px-3 py-2">Thời gian</th>
                  <th className="px-3 py-2">Action</th>
                  <th className="px-3 py-2">Bảng</th>
                  <th className="px-3 py-2">Record</th>
                  <th className="px-3 py-2">Actor</th>
                  <th className="px-3 py-2 text-right">Chi tiết</th>
                </tr>
              </thead>
              <tbody>
                {result?.rows.map((row) => (
                  <tr key={row.id} className="border-t border-slate-800 align-top">
                    <td className="whitespace-nowrap px-3 py-3 text-xs">{dateTime(row.occurred_at)}</td>
                    <td className="px-3 py-3">
                      <span className={`rounded-lg border px-2 py-1 text-[11px] font-semibold ${
                        row.action === 'INSERT'
                          ? 'border-emerald-900 text-emerald-300'
                          : row.action === 'UPDATE'
                            ? 'border-amber-900 text-amber-300'
                            : 'border-red-900 text-red-300'
                      }`}>
                        {row.action}
                      </span>
                    </td>
                    <td className="px-3 py-3 font-mono text-xs text-cyan-300">{row.table_name}</td>
                    <td className="max-w-60 truncate px-3 py-3 font-mono text-xs text-slate-400" title={row.record_id ?? ''}>
                      {row.record_id ?? '—'}
                    </td>
                    <td className="px-3 py-3">
                      <div>{row.actor_name || 'System / không xác định'}</div>
                      <div className="mt-1 text-xs text-slate-500">{row.actor_email || row.actor_user_id || '—'}</div>
                    </td>
                    <td className="px-3 py-3 text-right">
                      <button
                        type="button"
                        onClick={() => setSelected(row)}
                        className="rounded-lg border border-slate-700 px-3 py-1.5 text-xs hover:border-cyan-800"
                      >
                        Xem
                      </button>
                    </td>
                  </tr>
                ))}
                {result && !result.rows.length ? (
                  <tr>
                    <td colSpan={6} className="px-3 py-12 text-center text-sm text-slate-500">Không có audit event phù hợp.</td>
                  </tr>
                ) : null}
              </tbody>
            </table>
          </div>

          {result?.next_before_id ? (
            <button
              type="button"
              disabled={loading}
              onClick={() => void load(result.next_before_id, true)}
              className="mt-4 w-full rounded-xl border border-slate-700 px-4 py-2 text-sm hover:border-cyan-800 disabled:opacity-50 sm:w-auto"
            >
              Tải thêm
            </button>
          ) : null}
        </section>
      </div>

      {selected ? (
        <div className="fixed inset-0 z-[90] grid place-items-center overflow-auto bg-slate-950/85 p-3 backdrop-blur-sm">
          <section className="my-4 w-full max-w-6xl rounded-3xl border border-slate-700 bg-slate-900 p-4 shadow-2xl sm:p-6">
            <div className="flex flex-wrap items-start justify-between gap-3">
              <div>
                <div className="text-xs font-semibold uppercase tracking-[0.18em] text-cyan-400">
                  Audit #{selected.id} · {selected.action}
                </div>
                <h2 className="mt-2 text-lg font-bold text-white">
                  {selected.table_name} · {selected.record_id || 'không có record id'}
                </h2>
                <p className="mt-1 text-xs text-slate-500">{dateTime(selected.occurred_at)}</p>
              </div>
              <button
                type="button"
                onClick={() => setSelected(null)}
                className="rounded-xl border border-slate-700 px-3 py-2 text-sm"
              >
                Đóng
              </button>
            </div>

            <div className="mt-5 grid gap-4 lg:grid-cols-2">
              <JsonView label="Old data" value={selected.old_data} />
              <JsonView label="New data" value={selected.new_data} />
            </div>
          </section>
        </div>
      ) : null}
    </main>
  )
}
