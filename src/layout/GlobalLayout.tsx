import React from 'react'
import { FloatingGate } from '@/container/FloatingNavigation'

interface GlobalLayoutProps {
  children: React.ReactNode
}

export const GlobalLayout: React.FC<GlobalLayoutProps> = ({ children }) => {
  return (
    <div className="box-border relative min-h-screen">
      {children}
      <FloatingGate />
    </div>
  )
}

GlobalLayout.displayName = 'GlobalLayout'
