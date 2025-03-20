import cn from 'clsx'
import React from 'react'
import { FileTypeIcon } from '@/component/icon/filetype'
import {
  ChevronDownIcon,
  ChevronRightIcon,
  FolderIcon,
  FolderOpenIcon,
} from '@/component/icon/material'
import type { IFileTreeNode } from './context'
import { useFileTreeViewmodel } from './context'

interface IProps {
  readonly node: IFileTreeNode
  readonly currentFilepath: string | null
  readonly onNodeClick: (node: IFileTreeNode) => void
}

export const FileTreeNode: React.FC<IProps> = props => {
  const { node, currentFilepath, onNodeClick } = props
  const viewmodel = useFileTreeViewmodel()

  if (node.type === 'folder') {
    return (
      <div className={cn('select-none', { hidden: node.parentCollapsed })}>
        <div
          className="flex cursor-pointer items-center rounded px-1 py-1 hover:bg-gray-200 dark:hover:bg-gray-700"
          onClick={e => {
            e.stopPropagation()
            viewmodel.toggleCollapse(node)
          }}
          style={{ paddingLeft: `${node.depth * 12}px` }}
        >
          <span className="mr-1 flex-shrink-0">
            {node.collapsed ? <ChevronRightIcon /> : <ChevronDownIcon />}
          </span>
          <span className="mr-1 flex-shrink-0">
            {node.collapsed ? (
              <FolderIcon className="text-blue-500" />
            ) : (
              <FolderOpenIcon className="text-blue-500" />
            )}
          </span>
          <span className="truncate">{node.basename}</span>
        </div>
      </div>
    )
  }

  return (
    <div
      className={cn(
        'flex cursor-pointer items-center rounded px-1 py-1 hover:bg-gray-200 dark:hover:bg-gray-700',
        {
          hidden: node.parentCollapsed,
          'bg-blue-100 text-blue-700 dark:bg-blue-900/50 dark:text-blue-300':
            currentFilepath === node.filepath,
        },
      )}
      onClick={() => onNodeClick(node)}
      style={{ paddingLeft: `${node.depth * 12}px` }}
    >
      <span className="invisible mr-1 flex-shrink-0">
        <ChevronRightIcon />
      </span>
      <span className="mr-1 flex-shrink-0">
        <FileTypeIcon extname={node.extname} />
      </span>
      <span className="truncate">{node.basename}</span>
    </div>
  )
}
