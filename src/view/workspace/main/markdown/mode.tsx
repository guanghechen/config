import React from 'react'
import type { MarkdownModeEnum } from './types'

export const MarkdownModeToggle: React.FC<{
  mode: MarkdownModeEnum
  onToggle: () => void
}> = props => {
  const { mode, onToggle } = props
  return (
    <button
      className="fixed right-4 top-16 z-50 flex h-9 w-9 items-center justify-center rounded-full bg-gray-200 bg-opacity-70 text-gray-600 shadow-sm transition-all hover:bg-opacity-90 hover:text-gray-800 dark:bg-gray-700 dark:bg-opacity-70 dark:text-gray-300 dark:hover:bg-opacity-90 dark:hover:text-gray-100"
      onClick={onToggle}
      title={`Switch to ${mode === 'preview' ? 'AST' : 'preview'} mode`}
    >
      {mode === 'preview' ? (
        <svg
          xmlns="http://www.w3.org/2000/svg"
          className="h-5 w-5"
          viewBox="0 0 24 24"
          fill="currentColor"
        >
          <path d="M9.4 16.6L4.8 12l4.6-4.6L8 6l-6 6 6 6 1.4-1.4zm5.2 0l4.6-4.6-4.6-4.6L16 6l6 6-6 6-1.4-1.4z" />
        </svg>
      ) : (
        <svg
          xmlns="http://www.w3.org/2000/svg"
          className="h-5 w-5"
          viewBox="0 0 24 24"
          fill="currentColor"
        >
          <path d="M12 4.5C7 4.5 2.73 7.61 1 12c1.73 4.39 6 7.5 11 7.5s9.27-3.11 11-7.5c-1.73-4.39-6-7.5-11-7.5zM12 17c-2.76 0-5-2.24-5-5s2.24-5 5-5 5 2.24 5 5-2.24 5-5 5zm0-8c-1.66 0-3 1.34-3 3s1.34 3 3 3 3-1.34 3-3-1.34-3-3-3z" />
        </svg>
      )}
    </button>
  )
}

MarkdownModeToggle.displayName = 'MarkdownModeToggle'
