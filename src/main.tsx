import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './popup/style.css'
import { App } from './popup/App'

const rootElement = document.getElementById('root')
if (!rootElement) throw new Error('Missing popup root element.')

createRoot(rootElement).render(
  <StrictMode>
    <App />
  </StrictMode>,
)
