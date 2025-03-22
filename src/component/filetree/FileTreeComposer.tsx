import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { FileTreeViewMode, type FileTreeViewModel, type IFileTreeFileNode } from './context'
import { FileList } from './FileList'
import { FileTree } from './FileTree'

interface IProps {
  readonly viewmodel: FileTreeViewModel
  readonly onFileNodeClick: (node: IFileTreeFileNode) => void
}

export const FileTreeComposer: React.FC<IProps> = props => {
  const { viewmodel, onFileNodeClick } = props
  const searchKeyword: string = useStateValue(viewmodel.searchKeyword$)
  const mode: FileTreeViewMode = useStateValue(viewmodel.viewMode$)

  const onViewModeToggle = React.useCallback(() => {
    const snapshot: FileTreeViewMode = viewmodel.viewMode$.getSnapshot()
    const nextMode: FileTreeViewMode =
      snapshot === FileTreeViewMode.LIST ? FileTreeViewMode.TREE : FileTreeViewMode.LIST
    viewmodel.viewMode$.next(nextMode)
  }, [viewmodel])

  return (
    <div className="relative">
      <button
        className="absolute right-1 top-1 z-10 flex h-7 w-7 items-center justify-center rounded-md bg-gray-200 bg-opacity-60 text-gray-600 shadow-sm transition-all hover:bg-opacity-80 hover:text-gray-800 dark:bg-gray-700 dark:bg-opacity-60 dark:text-gray-300 dark:hover:bg-opacity-80 dark:hover:text-gray-100"
        onClick={onViewModeToggle}
        title={`Switch to ${mode === FileTreeViewMode.LIST ? 'tree' : 'list'} view`}
      >
        {mode === FileTreeViewMode.LIST ? (
          <svg
            xmlns="http://www.w3.org/2000/svg"
            className="h-5 w-5"
            viewBox="0 0 24 24"
            fill="currentColor"
          >
            <path d="M3 3h6v4H3V3zm0 6h6v4H3V9zm0 6h6v4H3v-4zm8-12h10v4H11V3zm0 6h10v4H11V9zm0 6h10v4H11v-4z" />
          </svg>
        ) : (
          <svg
            xmlns="http://www.w3.org/2000/svg"
            className="h-5 w-5"
            viewBox="0 0 24 24"
            fill="currentColor"
          >
            <path d="M3 13h2v-2H3v2zm0 4h2v-2H3v2zm0-8h2V7H3v2zm4 4h14v-2H7v2zm0 4h14v-2H7v2zM7 7v2h14V7H7z" />
          </svg>
        )}
      </button>

      {mode === FileTreeViewMode.LIST || searchKeyword.length > 0 ? (
        <FileList viewmodel={viewmodel} onFileNodeClick={onFileNodeClick} />
      ) : (
        <FileTree viewmodel={viewmodel} onFileNodeClick={onFileNodeClick} />
      )}
    </div>
  )
}
