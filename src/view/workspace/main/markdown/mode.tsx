import type { ISetState } from '@guanghechen/react-viewmodel'
import { useSetState, useStateValue } from '@guanghechen/react-viewmodel'
import cn from 'clsx'
import React from 'react'
import { MarkdownModeEnum, useWorkspaceViewmodel } from '@/context/workspace'

export const MarkdownModeToggle: React.FC = () => {
  const viewmodel = useWorkspaceViewmodel()
  const mode: MarkdownModeEnum = useStateValue(viewmodel.markdownMode$)
  const setMode: ISetState<MarkdownModeEnum> = useSetState(viewmodel.markdownMode$)

  return (
    <div
      className="flex h-5 select-none rounded-lg bg-gray-100 bg-opacity-80 text-sm shadow-md transition-all hover:bg-opacity-95 dark:bg-gray-800 dark:bg-opacity-80 dark:hover:bg-opacity-95"
      title={`Current mode: ${mode}`}
    >
      <button
        className={cn(
          'box-border px-3 transition-all duration-200 rounded-l-lg focus:outline-none focus:ring-0',
          mode === 0 || (mode & MarkdownModeEnum.VIEW) !== 0
            ? 'bg-indigo-500 bg-opacity-90 font-medium text-white shadow-inner'
            : 'text-gray-500 hover:bg-gray-200 hover:bg-opacity-50 dark:text-gray-300 dark:hover:bg-gray-700 dark:hover:bg-opacity-50',
        )}
        onClick={() => setMode(m => m ^ MarkdownModeEnum.VIEW)}
      >
        md
      </button>
      <button
        className={cn(
          'box-border px-3 transition-all duration-200 focus:outline-none focus:ring-0',
          (mode & MarkdownModeEnum.AST) !== 0
            ? 'bg-blue-500 bg-opacity-90 font-medium text-white shadow-inner'
            : 'text-gray-500 hover:bg-gray-200 hover:bg-opacity-50 dark:text-gray-300 dark:hover:bg-gray-700 dark:hover:bg-opacity-50',
        )}
        onClick={() => setMode(m => m ^ MarkdownModeEnum.AST)}
      >
        ast
      </button>
      <button
        className={cn(
          'box-border px-3 transition-all duration-200 focus:outline-none focus:ring-0',
          (mode & MarkdownModeEnum.TOC) !== 0
            ? 'bg-sky-500 bg-opacity-90 font-medium text-white shadow-inner'
            : 'text-gray-500 hover:bg-gray-200 hover:bg-opacity-50 dark:text-gray-300 dark:hover:bg-gray-700 dark:hover:bg-opacity-50',
        )}
        onClick={() => setMode(m => m ^ MarkdownModeEnum.TOC)}
      >
        toc
      </button>
      <button
        className={cn(
          'box-border px-3 transition-all duration-200 rounded-r-lg focus:outline-none focus:ring-0',
          (mode & MarkdownModeEnum.FM) !== 0
            ? 'bg-teal-500 bg-opacity-90 font-medium text-white shadow-inner'
            : 'text-gray-500 hover:bg-gray-200 hover:bg-opacity-50 dark:text-gray-300 dark:hover:bg-gray-700 dark:hover:bg-opacity-50',
        )}
        onClick={() => setMode(m => m ^ MarkdownModeEnum.FM)}
      >
        fm
      </button>
    </div>
  )
}

MarkdownModeToggle.displayName = 'MarkdownModeToggle'
