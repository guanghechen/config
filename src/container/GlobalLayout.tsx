import React from 'react'
import { FloatingGate } from '@/container/FloatingGate'

interface GlobalLayoutProps {
  children: React.ReactNode
}

export const GlobalLayout: React.FC<GlobalLayoutProps> = ({ children }) => {
  return (
    <React.Fragment>
      {children}
      <FloatingGate />
    </React.Fragment>
  )
}

GlobalLayout.displayName = 'GlobalLayout'
