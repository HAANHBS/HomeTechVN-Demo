import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import App from './App'
import { PwaShell } from './features/pwa/PwaShell'
import './index.css'

const rootElement = document.getElementById('root')
if (!rootElement) throw new Error('Không tìm thấy #root')

createRoot(rootElement).render(
  <StrictMode>
    <PwaShell>
      <App />
    </PwaShell>
  </StrictMode>,
)
