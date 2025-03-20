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
  const nodes = useStateValue(viewmodel.nodes$)
  useStateValue(viewmodel.forceRerenderTick$)

  const onNodeClick = useEventCallback((node: IFileTreeNode) => {
    if (node.type === 'file') {
      const data = viewmodel.dataMap$.getSnapshot().get(node.uuid)
      onFileNodeClick(node, data as IFileTreeFileNodeData)
    }
  })

  return (
    <div className="text-sm">
      {nodes.map(node => (
        <FileTreeNode key={node.uuid} node={node} onNodeClick={onNodeClick} />
      ))}
    </div>
  )
}
