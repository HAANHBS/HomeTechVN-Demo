import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'
import { VitePWA } from 'vite-plugin-pwa'

export default defineConfig({
  plugins: [
    react(),
    tailwindcss(),
    VitePWA({
      registerType: 'prompt',
      injectRegister: null,
      includeAssets: [
        'icons/apple-touch-icon.png',
        'icons/pwa-192x192.png',
        'icons/pwa-512x512.png',
        'icons/pwa-maskable-512x512.png',
      ],
      manifest: {
        id: '/',
        name: 'HomeTechVN - Quản lý cửa hàng',
        short_name: 'HomeTechVN',
        description: 'Quản lý khách hàng, bán hàng, sửa chữa, kho, bảo hành, dịch vụ và báo cáo cho HomeTechVN.',
        lang: 'vi',
        start_url: '/',
        scope: '/',
        display: 'standalone',
        display_override: ['window-controls-overlay', 'standalone', 'minimal-ui'],
        orientation: 'any',
        background_color: '#07101d',
        theme_color: '#0f172a',
        categories: ['business', 'productivity', 'utilities'],
        prefer_related_applications: false,
        icons: [
          {
            src: '/icons/pwa-192x192.png',
            sizes: '192x192',
            type: 'image/png',
            purpose: 'any',
          },
          {
            src: '/icons/pwa-512x512.png',
            sizes: '512x512',
            type: 'image/png',
            purpose: 'any',
          },
          {
            src: '/icons/pwa-maskable-512x512.png',
            sizes: '512x512',
            type: 'image/png',
            purpose: 'maskable',
          },
        ],
      },
      workbox: {
        cleanupOutdatedCaches: true,
        clientsClaim: false,
        skipWaiting: false,
        navigateFallback: '/index.html',
        globPatterns: ['**/*.{js,css,html,ico,png,svg,webmanifest}'],
        runtimeCaching: [],
        sourcemap: false,
      },
      devOptions: {
        enabled: false,
      },
    }),
  ],
  build: {
    sourcemap: false,
    chunkSizeWarningLimit: 800,
  },
})
