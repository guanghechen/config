'use client'

import { MathJaxProvider } from '@yozora/react-mathjax'
import React from 'react'
import { createRoot } from 'react-dom/client'
import { BrowserRouter, Route, Routes } from 'react-router-dom'
import { SiteContextProvider } from './context/site'
import { GlobalLayout } from './layout/GlobalLayout'
import { routes, views } from './route'
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
    <SiteContextProvider>
      <MathJaxProvider>
        <BrowserRouter>
          <GlobalLayout>
            <AppRoutes />
          </GlobalLayout>
        </BrowserRouter>
      </MathJaxProvider>
    </SiteContextProvider>
  )
}

// eslint-disable-next-line no-constant-condition
if (true) {
  createRoot(document.getElementById('root')!).render(
    <React.StrictMode>
      <App />
    </React.StrictMode>,
  )
} else {
  createRoot(document.getElementById('root')!).render(<App />)
}
