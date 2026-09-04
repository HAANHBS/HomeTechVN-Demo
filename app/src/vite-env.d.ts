/// <reference types="vite/client" />
/// <reference types="vite-plugin-pwa/react" />

interface BeforeInstallPromptEvent extends Event {
  prompt(): Promise<void>
  userChoice: Promise<{
    outcome: 'accepted' | 'dismissed'
    platform: string
  }>
}

interface ImportMetaEnv {
  readonly VITE_HOMETECHVN_DEMO_MODE?: 'true' | 'false'
  readonly VITE_HOMETECHVN_DEMO_ACCOUNTS?: string
  readonly VITE_HOMETECHVN_DEMO_PASSWORD?: string
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}
