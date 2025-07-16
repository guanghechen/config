import { MathJaxProvider } from '@yozora/react-mathjax'
import React from 'react'
import { createRoot } from 'react-dom/client'
import { BrowserRouter, Route, Routes } from 'react-router-dom'
import { SiteContextProvider } from './context/site'
import { GlobalLayout } from './view/layout'
import './index.css'

const WorkspaceView = React.lazy(() => import('@/view/workspace'))
const NotFoundView = React.lazy(() => import('@/view/not-found'))
const ExcalidrawPlayground = React.lazy(() => import('@/view/playground/excalidraw'))

const AppRoutes: React.FC = () => {
  return (
    <Routes>
      <Route path="/" Component={WorkspaceView} />
      <Route path="/workspace/" Component={WorkspaceView} />
      <Route path="/playground/excalidraw" Component={ExcalidrawPlayground} />
      <Route path="*" Component={NotFoundView} />
    </Routes>
  )
}

const App: React.FC = () => {
  return (
    <React.StrictMode>
      <React.Suspense fallback={<div>loading...</div>}>
        <MathJaxProvider>
          <SiteContextProvider>
            <BrowserRouter>
              <GlobalLayout>
                <AppRoutes />
              </GlobalLayout>
            </BrowserRouter>
          </SiteContextProvider>
        </MathJaxProvider>
      </React.Suspense>
    </React.StrictMode>
  )
}

createRoot(document.getElementById('root')!).render(<App />)
