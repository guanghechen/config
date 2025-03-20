import { useEventCallback } from '@guanghechen/react-hooks'
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
  readonly onNodeClick: (node: IFileTreeNode) => void
}

export const FileTreeNode: React.FC<IProps> = props => {
  const { node, onNodeClick: onNodeClickFromProps } = props
  const viewmodel = useFileTreeViewmodel()
  const collapsed: boolean = viewmodel.checkCollapsed(node)
  const visible: boolean = viewmodel.checkVisible(node)

  const onNodeClick = useEventCallback((): void => {
    onNodeClickFromProps(node)
  })

  if (node.type === 'folder') {
    return (
      <div className={cn('select-none', { hidden: !visible })}>
        <div
          className="flex cursor-pointer items-center rounded px-1 py-1 hover:bg-gray-200 dark:hover:bg-gray-700"
          onClick={e => {
            e.stopPropagation()
            viewmodel.onToggleCollapse(node.uuid)
          }}
          style={{ paddingLeft: `${node.depth * 12}px` }}
        >
          <span className="mr-1 flex-shrink-0">
            {collapsed ? <ChevronRightIcon /> : <ChevronDownIcon />}
          </span>
          <span className="mr-1 flex-shrink-0">
            {collapsed ? (
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
        { hidden: !visible },
      )}
      onClick={onNodeClick}
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
