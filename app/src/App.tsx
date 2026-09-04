import { useEffect, useMemo, useState, type ReactNode } from 'react'
import type { Session } from '@supabase/supabase-js'
import { LoginPage } from './features/auth/LoginPage'
import { CrmPage } from './features/crm/CrmPage'
import { InventoryPage } from './features/inventory/InventoryPage'
import { SalesPage } from './features/sales/SalesPage'
import { RepairPage } from './features/repair/RepairPage'
import { ChecklistPage } from './features/checklist/ChecklistPage'
import { WarrantyPage } from './features/warranty/WarrantyPage'
import { ServiceLicensePage } from './features/service_license/ServiceLicensePage'
import { ReminderPage } from './features/reminders/ReminderPage'
import { NotificationPage } from './features/notifications/NotificationPage'
import { DashboardPage } from './features/dashboard/DashboardPage'
import { ReportsPage } from './features/reports/ReportsPage'
import { AuditPage } from './features/audit/AuditPage'
import { PublicWarrantyPage } from './features/public_warranty/PublicWarrantyPage'
import { DemoModeBanner } from './features/demo/DemoModeBanner'
import { QrCommandCenter, type QrAction, type QrResolved, type QrRoute } from './features/qr/QrCommandCenter'
import { hasPermission, loadUserContext, type AppUserContext } from './lib/permissions'
import { supabase } from './lib/supabase'

type AuthState =
  | { status: 'loading' }
  | { status: 'signed-out' }
  | { status: 'ready'; session: Session; context: AppUserContext }
  | { status: 'blocked'; session: Session; message: string }

type Module = 'dashboard' | 'reports' | 'audit' | 'crm' | 'inventory' | 'sales' | 'repair' | 'checklist' | 'warranty' | 'service-license' | 'reminders' | 'notifications'

type PublicWarrantyRoute = { matched: false } | { matched: true; token: string | null }

function readPublicWarrantyRoute(): PublicWarrantyRoute {
  const path = window.location.pathname
  if (!path.startsWith('/w/')) return { matched: false }
  const raw = path.slice(3).replace(/\/$/, '').toLowerCase()
  return { matched: true, token: /^[0-9a-f]{64}$/.test(raw) ? raw : null }
}

function readInternalQrToken() {
  const raw = new URLSearchParams(window.location.search).get('qr')?.toLowerCase() ?? null
  return raw && /^[0-9a-f]{64}$/.test(raw) ? raw : null
}

export default function App() {
  const [session, setSession] = useState<Session | null | undefined>(undefined)
  const [context, setContext] = useState<AppUserContext | null>(null)
  const [contextError, setContextError] = useState<string | null>(null)
  const [contextLoading, setContextLoading] = useState(false)
  const [module, setModule] = useState<Module>('dashboard')
  const [initialQrToken, setInitialQrToken] = useState<string | null>(readInternalQrToken)
  const [qrHandoff, setQrHandoff] = useState<{ target: QrResolved; action: QrAction } | null>(null)
  const publicWarrantyRoute = useMemo(readPublicWarrantyRoute, [])

  useEffect(() => {
    let mounted = true

    void supabase.auth.getSession().then(({ data }) => {
      if (mounted) setSession(data.session)
    })

    const { data: subscription } = supabase.auth.onAuthStateChange((_event, nextSession) => {
      setSession(nextSession)
    })

    return () => {
      mounted = false
      subscription.subscription.unsubscribe()
    }
  }, [])

  useEffect(() => {
    if (!session) {
      setContext(null)
      setContextError(null)
      setContextLoading(false)
      return
    }

    let cancelled = false
    setContextLoading(true)
    setContextError(null)

    void loadUserContext(session.user.id)
      .then((nextContext) => {
        if (!cancelled) setContext(nextContext)
      })
      .catch((error: unknown) => {
        if (!cancelled) {
          setContext(null)
          setContextError(error instanceof Error ? error.message : 'Không đọc được quyền người dùng.')
        }
      })
      .finally(() => {
        if (!cancelled) setContextLoading(false)
      })

    return () => {
      cancelled = true
    }
  }, [session])

  const authState: AuthState = useMemo(() => {
    if (session === undefined) return { status: 'loading' }
    if (session === null) return { status: 'signed-out' }
    if (contextLoading) return { status: 'loading' }
    if (contextError || !context) {
      return {
        status: 'blocked',
        session,
        message: contextError ?? 'Tài khoản chưa sẵn sàng.',
      }
    }
    return { status: 'ready', session, context }
  }, [session, context, contextError, contextLoading])

  if (publicWarrantyRoute.matched) {
    return <PublicWarrantyPage token={publicWarrantyRoute.token} />
  }

  if (authState.status === 'loading') {
    return (
      <main className="grid min-h-screen place-items-center bg-slate-950 text-slate-200">
        <div className="rounded-2xl border border-slate-800 bg-slate-900 px-6 py-5">Đang tải HomeTechVN…</div>
      </main>
    )
  }

  if (authState.status === 'signed-out') return <LoginPage />

  if (authState.status === 'blocked') {
    return (
      <main className="grid min-h-screen place-items-center bg-slate-950 px-4 text-slate-100">
        <div className="max-w-lg rounded-3xl border border-amber-800 bg-slate-900 p-8">
          <h1 className="text-xl font-semibold text-amber-300">Tài khoản chưa được cấp quyền</h1>
          <p className="mt-3 text-slate-300">{authState.message}</p>
          <button
            type="button"
            className="mt-6 rounded-xl border border-slate-700 px-4 py-2 hover:bg-slate-800"
            onClick={() => void supabase.auth.signOut()}
          >
            Đăng xuất
          </button>
        </div>
      </main>
    )
  }

  const canOpenDashboard = hasPermission(authState.context, 'dashboard.view')
  const canOpenReports = hasPermission(authState.context, 'report.view')
  const canOpenAudit = hasPermission(authState.context, 'audit.view')
  const canOpenCrm = hasPermission(authState.context, 'customer.view') || hasPermission(authState.context, 'device.view')
  const canOpenInventory = hasPermission(authState.context, 'product.view') || hasPermission(authState.context, 'inventory.view')
  const canOpenSales = hasPermission(authState.context, 'sale.view')
  const canOpenRepair = hasPermission(authState.context, 'repair.view')
  const canOpenChecklist = hasPermission(authState.context, 'checklist.run') || hasPermission(authState.context, 'checklist.manage')
  const canOpenWarranty = hasPermission(authState.context, 'warranty.view')
  const canOpenServiceLicense = hasPermission(authState.context, 'service.view') || hasPermission(authState.context, 'license.view')
  const canOpenReminders = hasPermission(authState.context, 'notification.view') || hasPermission(authState.context, 'notification.manage')
  const canOpenNotifications = canOpenReminders

  function handleQrNavigate(route: QrRoute, target: QrResolved, action: QrAction) {
    setQrHandoff({ target, action })
    setInitialQrToken(null)
    setModule(route)
    const url = new URL(window.location.href)
    url.searchParams.delete('qr')
    window.history.replaceState({}, '', `${url.pathname}${url.search}${url.hash}`)
  }

  const qrControls = (
    <>
      <QrCommandCenter context={authState.context} initialToken={initialQrToken} onNavigate={handleQrNavigate} />
      {qrHandoff ? (
        <aside className="fixed bottom-20 right-5 z-30 max-w-sm rounded-2xl border border-cyan-800 bg-slate-950/95 p-3 text-sm text-slate-200 shadow-2xl" aria-live="polite">
          <div className="flex items-start gap-3">
            <div className="min-w-0 flex-1">
              <div className="text-xs font-semibold uppercase tracking-wider text-cyan-400">Đã mở từ QR · {qrHandoff.action}</div>
              <div className="mt-1 truncate font-mono text-white">{qrHandoff.target.label}</div>
              <div className="mt-1 text-xs text-slate-400">Chỉ các thao tác được quyền mới hiển thị và được Supabase chấp nhận.</div>
            </div>
            <button type="button" onClick={() => setQrHandoff(null)} className="rounded-lg border border-slate-700 px-2 py-1" aria-label="Đóng thông báo QR">✕</button>
          </div>
        </aside>
      ) : null}
    </>
  )

  const withDashboard = (node: ReactNode) => (
    <>
      <DemoModeBanner />
      {node}
      {qrControls}
      {canOpenDashboard && module !== 'dashboard' ? (
        <button type="button" className="global-home-button" onClick={() => setModule('dashboard')} aria-label="Quay về Tổng quan">
          <span aria-hidden="true">⌂</span>
          <span>Tổng quan</span>
        </button>
      ) : null}
    </>
  )

  if (module === 'dashboard' && canOpenDashboard) {
    return (
      <>
        <DemoModeBanner />
        <DashboardPage
          context={authState.context}
          onOpenCrm={canOpenCrm ? () => setModule('crm') : undefined}
          onOpenInventory={canOpenInventory ? () => setModule('inventory') : undefined}
          onOpenSales={canOpenSales ? () => setModule('sales') : undefined}
          onOpenRepair={canOpenRepair ? () => setModule('repair') : undefined}
          onOpenChecklist={canOpenChecklist ? () => setModule('checklist') : undefined}
          onOpenWarranty={canOpenWarranty ? () => setModule('warranty') : undefined}
          onOpenServiceLicense={canOpenServiceLicense ? () => setModule('service-license') : undefined}
          onOpenReminders={canOpenReminders ? () => setModule('reminders') : undefined}
          onOpenNotifications={canOpenNotifications ? () => setModule('notifications') : undefined}
          onOpenReports={canOpenReports ? () => setModule('reports') : undefined}
          onOpenAudit={canOpenAudit ? () => setModule('audit') : undefined}
        />
        {qrControls}
      </>
    )
  }

  if (module === 'reports' && canOpenReports) {
    return withDashboard(<ReportsPage context={authState.context} />)
  }

  if (module === 'audit' && canOpenAudit) {
    return withDashboard(<AuditPage context={authState.context} />)
  }

  if (module === 'notifications' && canOpenNotifications) {
    return withDashboard(<NotificationPage context={authState.context} initialTarget={qrHandoff?.target} initialAction={qrHandoff?.action} onOpenCrm={canOpenCrm ? () => setModule('crm') : undefined} onOpenReminders={canOpenReminders ? () => setModule('reminders') : undefined} />)
  }

  if (module === 'reminders' && canOpenReminders) {
    return withDashboard(<ReminderPage context={authState.context} initialTarget={qrHandoff?.target} initialAction={qrHandoff?.action} onOpenCrm={canOpenCrm ? () => setModule('crm') : undefined} onOpenRepair={canOpenRepair ? () => setModule('repair') : undefined} onOpenWarranty={canOpenWarranty ? () => setModule('warranty') : undefined} onOpenServiceLicense={canOpenServiceLicense ? () => setModule('service-license') : undefined} onOpenInventory={canOpenInventory ? () => setModule('inventory') : undefined} onOpenNotifications={canOpenNotifications ? () => setModule('notifications') : undefined} />)
  }

  if (module === 'service-license' && canOpenServiceLicense) {
    return withDashboard(<ServiceLicensePage context={authState.context} initialTarget={qrHandoff?.target} initialAction={qrHandoff?.action} onOpenCrm={canOpenCrm ? () => setModule('crm') : undefined} onOpenWarranty={canOpenWarranty ? () => setModule('warranty') : undefined} />)
  }

  if (module === 'warranty' && canOpenWarranty) {
    return withDashboard(<WarrantyPage context={authState.context} initialTarget={qrHandoff?.target} initialAction={qrHandoff?.action} onOpenCrm={canOpenCrm ? () => setModule('crm') : undefined} onOpenInventory={canOpenInventory ? () => setModule('inventory') : undefined} onOpenSales={canOpenSales ? () => setModule('sales') : undefined} onOpenRepair={canOpenRepair ? () => setModule('repair') : undefined} onOpenChecklist={canOpenChecklist ? () => setModule('checklist') : undefined} />)
  }

  if (module === 'checklist' && canOpenChecklist) {
    return withDashboard(<ChecklistPage context={authState.context} initialTarget={qrHandoff?.target} initialAction={qrHandoff?.action} onOpenCrm={canOpenCrm ? () => setModule('crm') : undefined} onOpenInventory={canOpenInventory ? () => setModule('inventory') : undefined} onOpenSales={canOpenSales ? () => setModule('sales') : undefined} onOpenRepair={canOpenRepair ? () => setModule('repair') : undefined} onOpenWarranty={canOpenWarranty ? () => setModule('warranty') : undefined} />)
  }

  if (module === 'repair' && canOpenRepair) {
    return withDashboard(<RepairPage context={authState.context} initialTarget={qrHandoff?.target} initialAction={qrHandoff?.action} onOpenCrm={canOpenCrm ? () => setModule('crm') : undefined} onOpenInventory={canOpenInventory ? () => setModule('inventory') : undefined} onOpenSales={canOpenSales ? () => setModule('sales') : undefined} onOpenChecklist={canOpenChecklist ? () => setModule('checklist') : undefined} onOpenWarranty={canOpenWarranty ? () => setModule('warranty') : undefined} />)
  }

  if (module === 'sales' && canOpenSales) {
    return withDashboard(<SalesPage context={authState.context} initialTarget={qrHandoff?.target} initialAction={qrHandoff?.action} onOpenCrm={canOpenCrm ? () => setModule('crm') : undefined} onOpenInventory={canOpenInventory ? () => setModule('inventory') : undefined} onOpenRepair={canOpenRepair ? () => setModule('repair') : undefined} onOpenChecklist={canOpenChecklist ? () => setModule('checklist') : undefined} onOpenWarranty={canOpenWarranty ? () => setModule('warranty') : undefined} />)
  }

  if (module === 'inventory' && canOpenInventory) {
    return withDashboard(<InventoryPage context={authState.context} initialTarget={qrHandoff?.target} initialAction={qrHandoff?.action} onOpenCrm={() => setModule('crm')} onOpenSales={canOpenSales ? () => setModule('sales') : undefined} onOpenRepair={canOpenRepair ? () => setModule('repair') : undefined} onOpenChecklist={canOpenChecklist ? () => setModule('checklist') : undefined} onOpenWarranty={canOpenWarranty ? () => setModule('warranty') : undefined} />)
  }

  if (canOpenCrm) {
    return withDashboard(<CrmPage context={authState.context} initialTarget={qrHandoff?.target} initialAction={qrHandoff?.action} onOpenInventory={canOpenInventory ? () => setModule('inventory') : undefined} onOpenSales={canOpenSales ? () => setModule('sales') : undefined} onOpenRepair={canOpenRepair ? () => setModule('repair') : undefined} onOpenChecklist={canOpenChecklist ? () => setModule('checklist') : undefined} onOpenWarranty={canOpenWarranty ? () => setModule('warranty') : undefined} onOpenServiceLicense={canOpenServiceLicense ? () => setModule('service-license') : undefined} onOpenReminders={canOpenReminders ? () => setModule('reminders') : undefined} onOpenNotifications={canOpenNotifications ? () => setModule('notifications') : undefined} />)
  }

  if (canOpenRepair) {
    return withDashboard(<RepairPage context={authState.context} onOpenInventory={canOpenInventory ? () => setModule('inventory') : undefined} onOpenSales={canOpenSales ? () => setModule('sales') : undefined} onOpenChecklist={canOpenChecklist ? () => setModule('checklist') : undefined} onOpenWarranty={canOpenWarranty ? () => setModule('warranty') : undefined} />)
  }

  if (canOpenSales) {
    return withDashboard(<SalesPage context={authState.context} onOpenInventory={canOpenInventory ? () => setModule('inventory') : undefined} onOpenRepair={canOpenRepair ? () => setModule('repair') : undefined} onOpenChecklist={canOpenChecklist ? () => setModule('checklist') : undefined} onOpenWarranty={canOpenWarranty ? () => setModule('warranty') : undefined} />)
  }

  if (canOpenInventory) {
    return withDashboard(<InventoryPage context={authState.context} onOpenCrm={() => setModule('crm')} onOpenSales={canOpenSales ? () => setModule('sales') : undefined} onOpenRepair={canOpenRepair ? () => setModule('repair') : undefined} onOpenChecklist={canOpenChecklist ? () => setModule('checklist') : undefined} onOpenWarranty={canOpenWarranty ? () => setModule('warranty') : undefined} />)
  }

  if (canOpenChecklist) {
    return withDashboard(<ChecklistPage context={authState.context} onOpenWarranty={canOpenWarranty ? () => setModule('warranty') : undefined} />)
  }

  if (canOpenWarranty) {
    return withDashboard(<WarrantyPage context={authState.context} />)
  }

  if (canOpenServiceLicense) {
    return withDashboard(<ServiceLicensePage context={authState.context} onOpenCrm={canOpenCrm ? () => setModule('crm') : undefined} onOpenWarranty={canOpenWarranty ? () => setModule('warranty') : undefined} />)
  }

  if (canOpenReminders) {
    return withDashboard(<ReminderPage context={authState.context} onOpenCrm={canOpenCrm ? () => setModule('crm') : undefined} onOpenRepair={canOpenRepair ? () => setModule('repair') : undefined} onOpenWarranty={canOpenWarranty ? () => setModule('warranty') : undefined} onOpenServiceLicense={canOpenServiceLicense ? () => setModule('service-license') : undefined} onOpenInventory={canOpenInventory ? () => setModule('inventory') : undefined} onOpenNotifications={canOpenNotifications ? () => setModule('notifications') : undefined} />)
  }

  if (canOpenAudit) {
    return withDashboard(<AuditPage context={authState.context} />)
  }

  if (canOpenReports) {
    return withDashboard(<ReportsPage context={authState.context} />)
  }

  if (canOpenNotifications) {
    return withDashboard(<NotificationPage context={authState.context} />)
  }

  return (
    <main className="grid min-h-screen place-items-center bg-slate-950 px-4 text-slate-100">
      <div className="rounded-3xl border border-amber-900 bg-slate-900 p-8">Không có quyền truy cập các module hiện tại.</div>
    </main>
  )
}
