import { MathJaxProvider } from '@yozora/react-mathjax'
import React from 'react'
import { createRoot } from 'react-dom/client'
import { MarkdownView } from '@/view/markdown'
import { SiteContextProvider } from './context/site'

const App: React.FC = () => {
  return (
    <React.StrictMode>
      <React.Suspense fallback={<div>loading...</div>}>
        <MathJaxProvider>
          <SiteContextProvider>
            <MarkdownView />
          </SiteContextProvider>
        </MathJaxProvider>
      </React.Suspense>
    </React.StrictMode>
  )
}

createRoot(document.getElementById('root')!).render(<App />)
