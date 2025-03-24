import { useStateValue } from '@guanghechen/react-viewmodel'
import cn from 'clsx'
import React from 'react'
import type { FileTreeViewModel, IFileTreeFileNode } from './context'
import { FiletreeMode } from './context'
import { FileList } from './FileList'
import { FileTree } from './FileTree'

interface IProps {
  readonly viewmodel: FileTreeViewModel
  readonly mode: FiletreeMode
  readonly onFileNodeClick: (node: IFileTreeFileNode) => void
  readonly onModeChange: (mode: FiletreeMode) => void
}

export const FileTreeComposer: React.FC<IProps> = props => {
  const { viewmodel, mode, onFileNodeClick, onModeChange } = props
  const searchKeyword: string = useStateValue(viewmodel.searchKeyword$)

  const listMode: boolean = mode === FiletreeMode.LIST || searchKeyword.length > 0
  const treeMode: boolean = mode === FiletreeMode.TREE && searchKeyword.length === 0

  return (
    <div>
      <div className="flex justify-end pr-2 pt-2">
        <div
          className="flex h-5 select-none rounded-lg bg-gray-200 bg-opacity-70 text-xs shadow-sm transition-all hover:bg-opacity-90 dark:bg-gray-700 dark:bg-opacity-70 dark:hover:bg-opacity-90"
          title={`Current view: ${mode === FiletreeMode.LIST ? 'list' : 'tree'}`}
        >
          <button
            className={cn(
              'box-border relative px-3 transition-all rounded-l-lg',
              listMode
                ? 'bg-indigo-500 bg-opacity-90 font-medium text-white'
                : 'text-gray-600 hover:text-gray-800 dark:text-gray-300 dark:hover:text-gray-100',
            )}
            onClick={() => onModeChange(FiletreeMode.LIST)}
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
            onClick={() => onModeChange(FiletreeMode.TREE)}
          >
            tree
          </button>
        </div>
      </div>
      <div>
        {mode === FiletreeMode.LIST || searchKeyword.length > 0 ? (
          <FileList viewmodel={viewmodel} onFileNodeClick={onFileNodeClick} />
        ) : (
          <FileTree viewmodel={viewmodel} onFileNodeClick={onFileNodeClick} />
        )}
      </div>
    </div>
  )
}
