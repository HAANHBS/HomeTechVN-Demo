export function DemoModeBanner() {
  const enabled = import.meta.env.VITE_HOMETECHVN_DEMO_MODE === 'true'

  if (!enabled) return null

  return (
    <div
      className="pointer-events-none fixed left-1/2 top-2 z-[80] -translate-x-1/2 rounded-full border border-amber-700/80 bg-amber-950/90 px-3 py-1.5 text-[11px] font-semibold uppercase tracking-[0.12em] text-amber-200 shadow-xl backdrop-blur"
      role="status"
      aria-label="Môi trường demo cục bộ"
    >
      LOCAL DEMO · KHÔNG DÙNG DỮ LIỆU THẬT
    </div>
  )
}
