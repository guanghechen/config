import React from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'

const App: React.FC = () => {
  return (
    <React.StrictMode>
      <React.Suspense fallback={<div>loading...</div>}>
        <h1>Tsuki</h1>
      </React.Suspense>
    </React.StrictMode>
  )
}

createRoot(document.getElementById('root')!).render((<App />) as any)
