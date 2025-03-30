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
      className="flex h-5 select-none rounded-lg bg-gray-200 bg-opacity-70 text-xs shadow-xs transition-all hover:bg-opacity-90 dark:bg-gray-700 dark:bg-opacity-70 dark:hover:bg-opacity-90"
      title={`Current view: ${mode === FileTreeModeEnum.LIST ? 'list' : 'tree'}`}
    >
      <button
        className={cn(
          'box-border relative px-3 transition-all rounded-l-lg',
          listMode
            ? 'bg-indigo-500 bg-opacity-90 font-medium text-white'
            : 'text-gray-600 hover:text-gray-800 dark:text-gray-300 dark:hover:text-gray-100',
        )}
        onClick={() => onModeChange(FileTreeModeEnum.LIST)}
      >
        list
      </button>
      <button
        className={cn(
          'box-border relative px-3 transition-all rounded-r-lg',
          treeMode
            ? 'bg-blue-500 bg-opacity-90 font-medium text-white'
            : 'text-gray-600 hover:text-gray-800 dark:text-gray-300 dark:hover:text-gray-100',
        )}
        onClick={() => onModeChange(FileTreeModeEnum.TREE)}
      >
        tree
      </button>
    </div>
  )
}
