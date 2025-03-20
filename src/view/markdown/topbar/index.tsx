import React from 'react'
import { ThemeToggle } from './ThemeToggle'

export const Topbar: React.FC = () => {
  return (
    <div className="flex items-center bg-neutral-200 px-4 py-2 dark:bg-neutral-800">
      <div className="ml-auto">
        <ThemeToggle />
      </div>
    </div>
  )
}
Topbar.displayName = 'MarkdownTopbar'
