import cn from 'clsx'
import React from 'react'
import type { IFileTreeNode } from './context'
import { FileTreeNode } from './FileTreeNode'

interface IProps {
  readonly node: IFileTreeNode
  readonly currentFilepath: string | null
  readonly onNodeClick: (node: IFileTreeNode) => void
}

const FileTreeItemComponent: React.FC<IProps> = props => {
  const { node, currentFilepath, onNodeClick } = props

  const activate: boolean = node.type === 'file' && node.filepath === currentFilepath
  const collapsed: boolean = node.type === 'folder' && node.collapsed

  return (
    <div
      className={cn('select-none px-1 py-1 hover:bg-gray-200 dark:hover:bg-gray-600', {
        'bg-gray-300 text-gray-800 dark:bg-gray-500 dark:text-gray-100': activate,
      })}
      style={{ paddingLeft: `${node.depth * 12}px` }}
      onClick={() => onNodeClick(node)}
    >
      <FileTreeNode node={node} collapsed={collapsed} />
    </div>
  )
}

export const FileTreeItem = React.memo(
  FileTreeItemComponent,
  (prevProps, nextProps) =>
    prevProps.node === nextProps.node &&
    prevProps.currentFilepath === nextProps.currentFilepath &&
    prevProps.onNodeClick === nextProps.onNodeClick,
)
FileTreeItem.displayName = 'FileTreeItem'
