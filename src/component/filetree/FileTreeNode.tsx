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
}

const FileTreeNodeInner: React.FC<IProps> = props => {
  const { node } = props

  if (node.type === 'folder') {
    return (
      <div className="flex cursor-pointer items-center">
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
  (prevProps, nextProps) => prevProps.node === nextProps.node,
)
