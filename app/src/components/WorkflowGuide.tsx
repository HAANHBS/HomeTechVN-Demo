export type WorkflowGuideStep = {
  label: string
  done: boolean
  detail?: string
}

export type WorkflowBlocker = {
  department: string
  action: string
}

export function WorkflowGuide({
  title,
  steps,
  blockers,
}: {
  title: string
  steps: WorkflowGuideStep[]
  blockers: WorkflowBlocker[]
}) {
  const currentIndex = steps.findIndex((step) => !step.done)

  return (
    <section className="rounded-2xl border border-cyan-950 bg-cyan-950/10 p-4" aria-live="polite">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <h3 className="font-semibold text-white">{title}</h3>
        <span className={`rounded-lg px-2 py-1 text-xs font-semibold ${blockers.length ? 'bg-amber-950 text-amber-300' : 'bg-emerald-950 text-emerald-300'}`}>
          {blockers.length ? `${blockers.length} việc cần hoàn thành` : 'Sẵn sàng cho bước tiếp theo'}
        </span>
      </div>

      <ol className="mt-3 grid gap-2 sm:grid-cols-2 xl:grid-cols-4">
        {steps.map((step, index) => {
          const current = index === currentIndex
          return (
            <li key={step.label} className={`rounded-xl border p-3 text-sm ${step.done ? 'border-emerald-900/70 bg-emerald-950/20' : current ? 'border-cyan-800 bg-cyan-950/30' : 'border-slate-800 bg-slate-950/40'}`}>
              <div className="flex items-start gap-2">
                <span className={`grid h-5 w-5 shrink-0 place-items-center rounded-full text-[11px] font-bold ${step.done ? 'bg-emerald-500 text-slate-950' : current ? 'bg-cyan-400 text-slate-950' : 'bg-slate-800 text-slate-400'}`}>
                  {step.done ? '✓' : index + 1}
                </span>
                <span>
                  <span className={step.done ? 'text-emerald-200' : current ? 'font-semibold text-cyan-200' : 'text-slate-400'}>{step.label}</span>
                  {step.detail ? <span className="mt-1 block text-xs text-slate-500">{step.detail}</span> : null}
                </span>
              </div>
            </li>
          )
        })}
      </ol>

      {blockers.length ? (
        <div className="mt-3 rounded-xl border border-amber-900/70 bg-amber-950/20 p-3">
          <div className="text-sm font-semibold text-amber-200">Hoàn thành các phần trước rồi mới chuyển bước:</div>
          <ul className="mt-2 space-y-1 text-sm text-amber-100/90">
            {blockers.map((blocker, index) => <li key={`${blocker.department}-${blocker.action}-${index}`}><strong>{blocker.department}:</strong> {blocker.action}</li>)}
          </ul>
        </div>
      ) : null}
    </section>
  )
}
