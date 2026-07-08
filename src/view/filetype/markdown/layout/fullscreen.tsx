import { useStateValue } from '@guanghechen/react-viewmodel'
import cn from 'clsx'
import React from 'react'
import { createPortal } from 'react-dom'
import { useMarkdownViewViewModel } from '../context'

export const FullscreenToggle: React.FC = () => {
  const viewmodel = useMarkdownViewViewModel()
  const contentFullWidth: boolean = useStateValue(viewmodel.contentFullWidth$)

  const portalTarget = React.useMemo(() => {
    return document.querySelector('.vl-fp-actions')
  }, [])

  const button = (
    <button
      type="button"
      title={contentFullWidth ? 'Restore width' : 'Full width'}
      onClick={() => viewmodel.contentFullWidth$.setState(v => !v)}
      className={cn(
        'flex items-center justify-center rounded-md text-xs font-medium',
        'p-1 bg-transparent border border-transparent transition-all duration-200',
        'text-gray-500 dark:text-gray-400 cursor-pointer',
        'hover:bg-gray-100 dark:hover:bg-white/10',
        'focus:outline-hidden focus:ring-2 focus:ring-blue-300/50',
      )}
    >
      {contentFullWidth ? (
        <svg
          width="14"
          height="14"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth="2"
          strokeLinecap="round"
          strokeLinejoin="round"
        >
          <polyline points="4,14 10,14 10,20" />
          <polyline points="20,10 14,10 14,4" />
          <line x1="14" y1="10" x2="21" y2="3" />
          <line x1="3" y1="21" x2="10" y2="14" />
        </svg>
      ) : (
        <svg
          width="14"
          height="14"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth="2"
          strokeLinecap="round"
          strokeLinejoin="round"
        >
          <polyline points="15,3 21,3 21,9" />
          <polyline points="9,21 3,21 3,15" />
          <line x1="21" y1="3" x2="14" y2="10" />
          <line x1="3" y1="21" x2="10" y2="14" />
        </svg>
      )}
    </button>
  )

  if (!portalTarget) {
    return null
  }

  return createPortal(button, portalTarget)
}

FullscreenToggle.displayName = 'MarkdownViewFullscreenToggle'
