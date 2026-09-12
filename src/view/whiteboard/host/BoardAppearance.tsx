import React from 'react'
import { ThemeToggle } from '@/container/ThemeToggle'
import { Settings } from '@/container/Settings'

export const BoardAppearance = React.memo(() => (
  <div className="wb-appearance">
    <ThemeToggle />
    <Settings />
  </div>
))
BoardAppearance.displayName = 'WhiteboardAppearance'
