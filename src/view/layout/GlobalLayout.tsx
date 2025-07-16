import React from 'react'
import { FloatingNavigation } from './FloatingNavigation'

interface GlobalLayoutProps {
  children: React.ReactNode
}

export const GlobalLayout: React.FC<GlobalLayoutProps> = ({ children }) => {
  return (
    <div className="relative min-h-screen">
      {children}
      <FloatingNavigation />
    </div>
  )
}

GlobalLayout.displayName = 'GlobalLayout'
