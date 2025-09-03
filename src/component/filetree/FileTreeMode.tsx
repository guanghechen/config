import { useStateValue } from '@guanghechen/react-viewmodel'
import cn from 'clsx'
import React from 'react'
import type { FileTreeViewModel } from './context'
import { FileTreeModeEnum } from './context'

interface IProps {
  readonly viewmodel: FileTreeViewModel
  readonly mode: FileTreeModeEnum
  readonly onModeChange: (mode: FileTreeModeEnum) => void
}

export const FileTreeMode: React.FC<IProps> = props => {
  const { viewmodel, mode, onModeChange } = props
  const searchKeyword: string = useStateValue(viewmodel.searchKeyword$)

  const listMode: boolean = mode === FileTreeModeEnum.LIST || searchKeyword.length > 0
  const treeMode: boolean = mode === FileTreeModeEnum.TREE && searchKeyword.length === 0

  return (
    <div
      className="flex h-5 select-none rounded-lg bg-gray-200 bg-opacity-80 text-xs shadow-md transition-all hover:bg-opacity-95 dark:bg-gray-600 dark:bg-opacity-90 dark:hover:bg-opacity-95"
      title={`Current view: ${mode === FileTreeModeEnum.LIST ? 'list' : 'tree'}`}
    >
      <button
        className={cn(
          'box-border relative px-3 transition-all duration-200 rounded-l-lg focus:outline-none focus:ring-0',
          listMode
            ? 'bg-indigo-500 bg-opacity-90 font-medium text-white shadow-inner'
            : 'text-gray-500 hover:bg-gray-200 hover:bg-opacity-50 dark:text-gray-300 dark:hover:bg-gray-700 dark:hover:bg-opacity-50',
        )}
        onClick={() => onModeChange(FileTreeModeEnum.LIST)}
      >
        list
      </button>
      <button
        className={cn(
          'box-border relative px-3 transition-all duration-200 rounded-r-lg focus:outline-none focus:ring-0',
          treeMode
            ? 'bg-blue-500 bg-opacity-90 font-medium text-white shadow-inner'
            : 'text-gray-500 hover:bg-gray-200 hover:bg-opacity-50 dark:text-gray-300 dark:hover:bg-gray-700 dark:hover:bg-opacity-50',
        )}
        onClick={() => onModeChange(FileTreeModeEnum.TREE)}
      >
        tree
      </button>
    </div>
  )
}
