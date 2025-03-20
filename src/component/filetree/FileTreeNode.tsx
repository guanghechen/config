import { useEventCallback } from '@guanghechen/react-hooks'
import React from 'react'
import { FileTypeIcon } from '@/component/icon/filetype'
import {
  ChevronDownIcon,
  ChevronRightIcon,
  FolderIcon,
  FolderOpenIcon,
} from '@/component/icon/material'
import type { IFileTreeFolderNode, IFileTreeNode, IFileTreeNodeData } from './context'
import { useFileTreeViewmodel } from './context'

interface IProps {
  readonly node: IFileTreeNode
  readonly data: IFileTreeNodeData
  readonly onNodeClick: (node: IFileTreeNode) => void
}

export const FileTreeNode: React.FC<IProps> = ({ node, data, onNodeClick }) => {
  const viewmodel = useFileTreeViewmodel()
  const collapsed = data.collapsed !== false

  const onToggleCollapse = useEventCallback((e: React.MouseEvent): void => {
    e.stopPropagation()
    if (node.type === 'folder') {
      const newDataMap = new Map(viewmodel.dataMap$.getSnapshot())
      const nodeData = { ...newDataMap.get(node.uuid)! }
      nodeData.collapsed = !nodeData.collapsed
      newDataMap.set(node.uuid, nodeData)
      viewmodel.dataMap$.next(newDataMap)
    }
  })

  const handleNodeClick = (): void => {
    onNodeClick(node)
  }

  if (node.type === 'folder') {
    const folderNode = node as IFileTreeFolderNode
    return (
      <div className="select-none">
        <div
          className="flex cursor-pointer items-center rounded px-1 py-1 hover:bg-gray-200 dark:hover:bg-gray-700"
          onClick={onToggleCollapse}
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

        {!collapsed && (
          <div>
            {folderNode.children.map(childNode => {
              const childData = viewmodel.dataMap$.getSnapshot().get(childNode.uuid)!
              return (
                <FileTreeNode
                  key={childNode.uuid}
                  node={childNode}
                  data={childData}
                  onNodeClick={onNodeClick}
                />
              )
            })}
          </div>
        )}
      </div>
    )
  }

  return (
    <div
      className="flex cursor-pointer items-center rounded px-1 py-1 hover:bg-gray-200 dark:hover:bg-gray-700"
      onClick={handleNodeClick}
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
