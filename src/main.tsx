import { MathJaxProvider } from '@yozora/react-mathjax'
import React from 'react'
import { createRoot } from 'react-dom/client'
import { BrowserRouter, Route, Routes } from 'react-router-dom'
import { SiteContextProvider } from './context/site'
import { routes, views } from './route'
import { GlobalLayout } from './view/layout'
import './index.css'

const AppRoutes: React.FC = () => {
  return (
    <Routes>
      <Route path="/" Component={views.workspace} />
      {routes.map(route => (
        <Route key={route.key} path={route.path} Component={route.Component} />
      ))}
      <Route path="*" Component={views.notfound} />
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
