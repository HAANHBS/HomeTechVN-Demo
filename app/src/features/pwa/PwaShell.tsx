import { useEffect, useRef, useState, type ReactNode } from 'react'
import { useRegisterSW } from 'virtual:pwa-register/react'

function isStandalone() {
  return window.matchMedia('(display-mode: standalone)').matches
}

export function PwaShell({ children }: { children: ReactNode }) {
  const [online, setOnline] = useState(() => navigator.onLine)
  const [installPrompt, setInstallPrompt] = useState<BeforeInstallPromptEvent | null>(null)
  const [installed, setInstalled] = useState(isStandalone)
  const [installBusy, setInstallBusy] = useState(false)
  const registrationRef = useRef<ServiceWorkerRegistration | null>(null)

  const {
    offlineReady: [offlineReady, setOfflineReady],
    needRefresh: [needRefresh, setNeedRefresh],
    updateServiceWorker,
  } = useRegisterSW({
    immediate: true,
    onRegisteredSW(_swUrl, registration) {
      registrationRef.current = registration ?? null
    },
    onRegisterError(error) {
      console.error('[PWA] Service Worker registration failed', error)
    },
  })

  useEffect(() => {
    const onOnline = () => setOnline(true)
    const onOffline = () => setOnline(false)
    const onInstalled = () => {
      setInstalled(true)
      setInstallPrompt(null)
    }
    const onBeforeInstall = (event: Event) => {
      const promptEvent = event as BeforeInstallPromptEvent
      promptEvent.preventDefault()
      setInstallPrompt(promptEvent)
    }

    window.addEventListener('online', onOnline)
    window.addEventListener('offline', onOffline)
    window.addEventListener('appinstalled', onInstalled)
    window.addEventListener('beforeinstallprompt', onBeforeInstall)

    const media = window.matchMedia('(display-mode: standalone)')
    const onDisplayMode = () => setInstalled(media.matches)
    media.addEventListener?.('change', onDisplayMode)

    return () => {
      window.removeEventListener('online', onOnline)
      window.removeEventListener('offline', onOffline)
      window.removeEventListener('appinstalled', onInstalled)
      window.removeEventListener('beforeinstallprompt', onBeforeInstall)
      media.removeEventListener?.('change', onDisplayMode)
    }
  }, [])

  useEffect(() => {
    const interval = window.setInterval(() => {
      if (!navigator.onLine) return
      const registration = registrationRef.current
      if (!registration || registration.installing || registration.waiting) return
      void registration.update().catch((error: unknown) => {
        console.warn('[PWA] Periodic update check failed', error)
      })
    }, 60 * 60 * 1000)

    return () => window.clearInterval(interval)
  }, [])

  async function install() {
    if (!installPrompt || installBusy) return
    setInstallBusy(true)
    try {
      await installPrompt.prompt()
      const choice = await installPrompt.userChoice
      if (choice.outcome === 'accepted') setInstallPrompt(null)
    } finally {
      setInstallBusy(false)
    }
  }

  const publicWarranty = window.location.pathname.startsWith('/w/')

  return (
    <>
      {children}

      {!online ? (
        <div className="pwa-offline-lock" role="alertdialog" aria-modal="true" aria-labelledby="pwa-offline-title">
          <section className="pwa-offline-card">
            <div className="pwa-offline-icon" aria-hidden="true">⌁</div>
            <h1 id="pwa-offline-title">Đang mất kết nối Internet</h1>
            <p>
              HomeTechVN chỉ cache phần giao diện ứng dụng. Dữ liệu nghiệp vụ không được cache để chỉnh sửa offline và
              hệ thống không xếp hàng giao dịch nền.
            </p>
            <div className="pwa-offline-warning">
              Khi offline: không bán hàng, không nhập/xuất kho, không cập nhật sửa chữa, bảo hành, dịch vụ, license hay cấu hình.
            </div>
            <button type="button" onClick={() => window.location.reload()}>
              Thử kết nối lại
            </button>
            <p className="pwa-offline-note">Khi Internet hoạt động trở lại, tải lại ứng dụng để tiếp tục.</p>
          </section>
        </div>
      ) : null}

      {online && needRefresh ? (
        <div className="pwa-toast pwa-toast-update" role="status">
          <div>
            <strong>Có phiên bản HomeTechVN mới</strong>
            <p>Nên cập nhật khi đã hoàn tất thao tác đang nhập để tránh mất dữ liệu chưa lưu.</p>
          </div>
          <div className="pwa-toast-actions">
            <button type="button" onClick={() => void updateServiceWorker(true)}>Cập nhật</button>
            <button type="button" className="secondary" onClick={() => setNeedRefresh(false)}>Để sau</button>
          </div>
        </div>
      ) : null}

      {online && offlineReady && !needRefresh ? (
        <div className="pwa-toast" role="status">
          <div>
            <strong>App shell đã sẵn sàng</strong>
            <p>Có thể mở giao diện khi mất mạng; mọi dữ liệu và giao dịch vẫn yêu cầu Internet.</p>
          </div>
          <button type="button" className="secondary" onClick={() => setOfflineReady(false)}>Đã hiểu</button>
        </div>
      ) : null}

      {online && !installed && installPrompt && !publicWarranty && !needRefresh ? (
        <button
          type="button"
          className="pwa-install-button"
          onClick={() => void install()}
          disabled={installBusy}
          aria-label="Cài HomeTechVN lên thiết bị"
        >
          <span aria-hidden="true">＋</span>
          <span>{installBusy ? 'Đang mở…' : 'Cài ứng dụng'}</span>
        </button>
      ) : null}
    </>
  )
}
