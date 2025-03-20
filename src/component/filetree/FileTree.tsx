import { useEventCallback } from '@guanghechen/react-hooks'
import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { FileTreeNode } from '@/component/filetree'
import type {
  FileTreeViewModel,
  IFileTreeFileNode,
  IFileTreeFileNodeData,
  IFileTreeNode,
} from './context'

interface IProps {
  readonly viewmodel: FileTreeViewModel
  readonly onFileNodeClick: (
    node: IFileTreeFileNode,
    data: IFileTreeFileNodeData | undefined,
  ) => void
}

export const FileTree: React.FC<IProps> = props => {
  const { viewmodel, onFileNodeClick } = props
  const root = useStateValue(viewmodel.root$)
  const dataMap = useStateValue(viewmodel.dataMap$)

  const onNodeClick = useEventCallback((node: IFileTreeNode) => {
    if (node.type === 'file') {
      const data = viewmodel.dataMap$.getSnapshot().get(node.uuid)
      onFileNodeClick(node, data as IFileTreeFileNodeData)
    }
  })

  if (!root) {
    return <div className="p-4">Loading file tree...</div>
  }

  return (
    <div className="text-sm">
      {root.children.map(node => {
        const nodeData = dataMap.get(node.uuid)!
        return (
          <FileTreeNode key={node.uuid} node={node} data={nodeData} onNodeClick={onNodeClick} />
        )
      })}
    </div>
  )
}
