import React from 'react'
import { FloatingGate } from './FloatingNavigation'

interface GlobalLayoutProps {
  children: React.ReactNode
}

export const GlobalLayout: React.FC<GlobalLayoutProps> = ({ children }) => {
  return (
    <div className="relative min-h-screen">
      {children}
      <FloatingGate />
    </div>
  )
}

GlobalLayout.displayName = 'GlobalLayout'
