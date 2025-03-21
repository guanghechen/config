import React from 'react'
import { FileTypeIcon } from '@/component/icon/filetype'
import {
  ChevronDownIcon,
  ChevronRightIcon,
  FolderIcon,
  FolderOpenIcon,
} from '@/component/icon/material'
import type { IFileTreeNode } from './context'

interface IProps {
  readonly node: IFileTreeNode
  readonly collapsed?: boolean | undefined
}

const FileTreeNodeInner: React.FC<IProps> = props => {
  const { node } = props

  if (node.type === 'folder') {
    const { collapsed = node.collapsed } = props
    return (
      <div className="flex cursor-pointer items-center">
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
    )
  }

  return (
    <div className="flex cursor-pointer items-center">
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

export const FileTreeNode = React.memo(
  FileTreeNodeInner,
  (prevProps, nextProps) =>
    prevProps.node === nextProps.node && //
    prevProps.collapsed === nextProps.collapsed,
)

FileTreeNode.displayName = 'FileTreeNode'
