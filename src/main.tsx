import { MathJaxProvider } from '@yozora/react-mathjax'
import React from 'react'
import { createRoot } from 'react-dom/client'
import { WorkspaceView } from '@/view/workspace'
import { SiteContextProvider } from './context/site'
import './index.css'

const App: React.FC = () => {
  return (
    <React.StrictMode>
      <React.Suspense fallback={<div>loading...</div>}>
        <MathJaxProvider>
          <SiteContextProvider>
            <WorkspaceView />
          </SiteContextProvider>
        </MathJaxProvider>
      </React.Suspense>
    </React.StrictMode>
  )
}

createRoot(document.getElementById('root')!).render(<App />)
