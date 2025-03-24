import { useStateValue } from '@guanghechen/react-viewmodel'
import cn from 'clsx'
import React from 'react'
import { MarkdownModeEnum, useWorkspaceViewmodel } from '../../context'

export const MarkdownModeToggle: React.FC = () => {
  const viewmodel = useWorkspaceViewmodel()
  const mode: MarkdownModeEnum = useStateValue(viewmodel.markdownMode$)

  return (
    <div
      className="fixed right-4 top-16 z-50 flex h-5 select-none rounded-lg bg-gray-200 bg-opacity-70 text-xs shadow-sm transition-all hover:bg-opacity-90 dark:bg-gray-700 dark:bg-opacity-70 dark:hover:bg-opacity-90"
      title={`Current mode: ${mode}`}
    >
      <button
        className={cn(
          'box-border relative px-3 transition-all rounded-l-lg',
          mode === MarkdownModeEnum.PREVIEW
            ? 'bg-indigo-500 bg-opacity-90 font-medium text-white'
            : 'text-gray-600 hover:text-gray-800 dark:text-gray-300 dark:hover:text-gray-100',
        )}
        onClick={() => viewmodel.markdownMode$.next(MarkdownModeEnum.PREVIEW)}
      >
        md
        {mode !== MarkdownModeEnum.PREVIEW && mode !== MarkdownModeEnum.AST && (
          <div className="absolute bottom-1 right-0 top-1 w-px bg-gray-300 dark:bg-gray-500" />
        )}
      </button>
      <button
        className={cn(
          'box-border relative px-3 transition-all',
          mode === MarkdownModeEnum.AST
            ? 'bg-blue-500 bg-opacity-90 font-medium text-white'
            : 'text-gray-600 hover:text-gray-800 dark:text-gray-300 dark:hover:text-gray-100',
        )}
        onClick={() => viewmodel.markdownMode$.next(MarkdownModeEnum.AST)}
      >
        ast
        {mode !== MarkdownModeEnum.AST && mode !== MarkdownModeEnum.SBS && (
          <div className="absolute bottom-1 right-0 top-1 w-px bg-gray-300 dark:bg-gray-500" />
        )}
      </button>
      <button
        className={cn(
          'box-border relative px-3 transition-all rounded-r-lg',
          mode === MarkdownModeEnum.SBS
            ? 'bg-amber-500 bg-opacity-90 font-medium text-white'
            : 'text-gray-600 hover:text-gray-800 dark:text-gray-300 dark:hover:text-gray-100',
        )}
        onClick={() => viewmodel.markdownMode$.next(MarkdownModeEnum.SBS)}
      >
        sbs
      </button>
    </div>
  )
}

MarkdownModeToggle.displayName = 'MarkdownModeToggle'
