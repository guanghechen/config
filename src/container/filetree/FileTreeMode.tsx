import { useStateValue } from '@guanghechen/react-viewmodel'
import cn from '@/common/util/clsx'
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
      className="flex h-5 select-none rounded-lg border border-[var(--vscode-border)] bg-[var(--vscode-sidebar-background)] text-xs shadow-sm transition-colors"
      title={`Current view: ${mode === FileTreeModeEnum.LIST ? 'list' : 'tree'}`}
    >
      <button
        className={cn(
          'box-border relative px-3 transition-all duration-200 rounded-l-lg focus:outline-none focus:ring-0',
          listMode
            ? 'bg-[var(--vscode-accent)] font-medium text-white shadow-inner'
            : 'text-[var(--vscode-muted-foreground)] hover:bg-[var(--vscode-list-hover-background)] hover:text-[var(--vscode-foreground)]',
        )}
        onClick={() => onModeChange(FileTreeModeEnum.LIST)}
      >
        list
      </button>
      <button
        className={cn(
          'box-border relative px-3 transition-all duration-200 rounded-r-lg focus:outline-none focus:ring-0',
          treeMode
            ? 'bg-[var(--vscode-accent)] font-medium text-white shadow-inner'
            : 'text-[var(--vscode-muted-foreground)] hover:bg-[var(--vscode-list-hover-background)] hover:text-[var(--vscode-foreground)]',
        )}
        onClick={() => onModeChange(FileTreeModeEnum.TREE)}
      >
        tree
      </button>
    </div>
  )
}
