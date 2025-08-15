'use client'

import { MathJaxProvider } from '@yozora/react-mathjax'
import React from 'react'
import { createRoot } from 'react-dom/client'
import { BrowserRouter, Route, Routes } from 'react-router-dom'
import { ToastContainer } from 'react-toastify'
import { SiteContextProvider } from './context/site'
import { GlobalLayout } from './layout/GlobalLayout'
import { routes, views } from './route'
import 'react-toastify/dist/ReactToastify.css'
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
      <ToastContainer
        position="top-right"
        autoClose={3000}
        hideProgressBar={false}
        newestOnTop={false}
        closeOnClick={true}
        rtl={false}
        pauseOnFocusLoss={true}
        draggable={true}
        pauseOnHover={true}
        theme="light"
        toastClassName="custom-toast"
      />
    </SiteContextProvider>
  )
}

createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
)
