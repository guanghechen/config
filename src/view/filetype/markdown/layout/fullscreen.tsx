import { useStateValue } from '@guanghechen/react-viewmodel'
import cn from '@/common/util/clsx'
import React from 'react'
import { useMarkdownViewViewModel } from '../context'

export const FullscreenToggle: React.FC = () => {
  const viewmodel = useMarkdownViewViewModel()
  const contentFullWidth: boolean = useStateValue(viewmodel.contentFullWidth$)
  const label = contentFullWidth ? 'Restore content width' : 'Use full content width'

  return (
    <button
      type="button"
      title={label}
      aria-label={label}
      aria-pressed={contentFullWidth}
      onClick={() => viewmodel.contentFullWidth$.setState(v => !v)}
      className={cn(
        'pointer-events-auto flex h-7 w-7 items-center justify-center rounded-md',
        'border border-transparent bg-white/70 text-xs font-medium shadow-sm backdrop-blur-sm',
        'transition-all duration-200 dark:bg-gray-800/70',
        'text-gray-500 dark:text-gray-400 cursor-pointer',
        'hover:bg-gray-100 dark:hover:bg-white/10',
        'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-blue-500',
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
}

FullscreenToggle.displayName = 'MarkdownViewFullscreenToggle'
