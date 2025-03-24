import cn from 'clsx'
import React from 'react'
import { MarkdownModeEnum } from './types'

interface IProps {
  readonly mode: MarkdownModeEnum
  readonly setMode: (nextMode: MarkdownModeEnum) => void
}

export const MarkdownModeToggle: React.FC<IProps> = props => {
  const { mode, setMode } = props
  return (
    <div
      className="fixed right-4 top-16 z-50 flex h-7 select-none rounded-lg bg-gray-200 bg-opacity-70 text-sm shadow-sm transition-all hover:bg-opacity-90 dark:bg-gray-700 dark:bg-opacity-70 dark:hover:bg-opacity-90"
      title={`Current mode: ${mode}`}
    >
      <button
        className={cn(
          'relative px-3 py-1 transition-all rounded-l-lg',
          mode === MarkdownModeEnum.PREVIEW
            ? 'bg-indigo-500 bg-opacity-90 font-medium text-white'
            : 'text-gray-600 hover:text-gray-800 dark:text-gray-300 dark:hover:text-gray-100',
        )}
        onClick={() => setMode(MarkdownModeEnum.PREVIEW)}
      >
        md
        {mode !== MarkdownModeEnum.PREVIEW && (
          <div className="absolute bottom-1 right-0 top-1 w-px bg-gray-300 dark:bg-gray-500" />
        )}
      </button>
      <button
        className={cn(
          'relative px-3 py-1 transition-all',
          mode === MarkdownModeEnum.AST
            ? 'bg-blue-500 bg-opacity-90 font-medium text-white'
            : 'text-gray-600 hover:text-gray-800 dark:text-gray-300 dark:hover:text-gray-100',
        )}
        onClick={() => setMode(MarkdownModeEnum.AST)}
      >
        ast
        {mode !== MarkdownModeEnum.AST && (
          <div className="absolute bottom-1 right-0 top-1 w-px bg-gray-300 dark:bg-gray-500" />
        )}
      </button>
      <button
        className={cn(
          'relative px-3 py-1 transition-all rounded-r-lg',
          mode === MarkdownModeEnum.SBS
            ? 'bg-amber-500 bg-opacity-90 font-medium text-white'
            : 'text-gray-600 hover:text-gray-800 dark:text-gray-300 dark:hover:text-gray-100',
        )}
        onClick={() => setMode(MarkdownModeEnum.SBS)}
      >
        sbs
      </button>
    </div>
  )
}

MarkdownModeToggle.displayName = 'MarkdownModeToggle'
