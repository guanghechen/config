import { useEventCallback } from '@guanghechen/react-hooks'
import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import type {
  IFileTreeFileNode,
  IFileTreeFolderNode,
  IFileTreeNode,
  IFileTreeNodeData,
} from '@/component/filetree/context'
import { useFileTreeViewmodel } from '@/component/filetree/context'
import { FileTypeIcon } from '@/component/icon/filetype'
import {
  ChevronDownIcon,
  ChevronRightIcon,
  FolderIcon,
  FolderOpenIcon,
} from '@/component/icon/material'
import { useSiteViewmodel } from '@/context/site'
import { useWorkspaceFiles } from '@/hook/useWorkspaceFiles'

interface IProps {
  readonly node: IFileTreeNode
  readonly data: IFileTreeNodeData
  readonly onNodeClick: (node: IFileTreeNode) => void
}

export const FileTreeNode: React.FC<IProps> = ({ node, data, onNodeClick }) => {
  const viewmodel = useFileTreeViewmodel()
  const isCollapsed = data.collapsed !== false

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

  if (node.type === 'folder' || node.type === 'root') {
    const folderNode = node as IFileTreeFolderNode
    return (
      <div className="select-none">
        <div
          className="flex cursor-pointer items-center rounded px-1 py-1 hover:bg-gray-200 dark:hover:bg-gray-700"
          onClick={onToggleCollapse}
          style={{ paddingLeft: `${data.depth * 12}px` }}
        >
          <span className="mr-1 flex-shrink-0">
            {isCollapsed ? <ChevronRightIcon /> : <ChevronDownIcon />}
          </span>
          <span className="mr-1 flex-shrink-0">
            {isCollapsed ? (
              <FolderIcon className="text-amber-500" />
            ) : (
              <FolderOpenIcon className="text-amber-500" />
            )}
          </span>
          <span className="truncate">{data.basename}</span>
        </div>

        {!isCollapsed && (
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
      style={{ paddingLeft: `${data.depth * 12}px` }}
    >
      <span className="invisible mr-1 flex-shrink-0">
        <ChevronRightIcon />
      </span>
      <span className="mr-1 flex-shrink-0">
        <FileTypeIcon extname={node.extname} />
      </span>
      <span className="truncate">{data.basename}</span>
    </div>
  )
}

export const FileTree: React.FC = () => {
  const siteViewmodel = useSiteViewmodel()
  const filetreeViewmodel = useFileTreeViewmodel()

  const workspace: string | null = useStateValue(siteViewmodel.workspace$)
  const root = useStateValue(filetreeViewmodel.root$)
  const dataMap = useStateValue(filetreeViewmodel.dataMap$)

  const { files } = useWorkspaceFiles(workspace, 0)

  React.useEffect(() => {
    filetreeViewmodel.updateFromFilepaths(files)
  }, [files])

  const onNodeClick = useEventCallback((node: IFileTreeNode) => {
    if (node.type === 'file') {
      const data = filetreeViewmodel.dataMap$.getSnapshot().get(node.uuid)!
      siteViewmodel.filepath$.next(data.filepath || node.uuid)
    }
  })

  if (!root) {
    return <div className="p-4">Loading file tree...</div>
  }

  return (
    <div className="h-full overflow-auto text-sm">
      {root.children.map(node => {
        const nodeData = dataMap.get(node.uuid)!
        return (
          <FileTreeNode key={node.uuid} node={node} data={nodeData} onNodeClick={onNodeClick} />
        )
      })}
    </div>
  )
}
