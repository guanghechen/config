'use client'

import { MathJaxProvider } from '@yozora/react-mathjax'
import React from 'react'
import { createRoot } from 'react-dom/client'
import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom'
import { ToastContainer } from 'react-toastify'
import { GlobalLayout } from './container/GlobalLayout'
import { AuthContextProvider } from './context/auth'
import { SiteContextProvider } from './context/site'
import { routes, views } from './route'

import 'react-toastify/dist/ReactToastify.css'
import './style/index.css'

const AppRoutes: React.FC = () => {
  return (
    <Routes>
      <Route path="/" element={<Navigate to="/whiteboard" replace={true} />} />
      {routes.map(route => (
        <Route key={route.key} path={route.path} Component={route.Component} />
      ))}
      <Route path="*" Component={views.notfound} />
    </Routes>
  )
}

const App: React.FC = () => {
  return (
    <React.Fragment>
      <AuthContextProvider>
        <SiteContextProvider>
          <MathJaxProvider>
            <BrowserRouter>
              <GlobalLayout>
                <AppRoutes />
              </GlobalLayout>
            </BrowserRouter>
          </MathJaxProvider>
        </SiteContextProvider>
      </AuthContextProvider>
      <ToastContainer
        position="top-center"
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
    </React.Fragment>
  )
}

createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
)
