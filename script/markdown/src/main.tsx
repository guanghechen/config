import React from 'react'
import { createRoot } from 'react-dom/client'
import { MarkdownView } from '@/view/markdown'

const App: React.FC = () => {
  return (
    <React.StrictMode>
      <React.Suspense fallback={<div>loading...</div>}>
        <MarkdownView />
      </React.Suspense>
    </React.StrictMode>
  )
}

createRoot(document.getElementById('root')!).render(<App />)
