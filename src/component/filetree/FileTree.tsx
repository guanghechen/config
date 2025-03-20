import { useEventCallback } from '@guanghechen/react-hooks'
import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { FileTreeNode } from '@/component/filetree'
import type { FileTreeViewModel, IFileTreeFileNode, IFileTreeNode } from './context'

interface IProps {
  readonly viewmodel: FileTreeViewModel
  readonly onFileNodeClick: (node: IFileTreeFileNode) => void
}

export const FileTree: React.FC<IProps> = props => {
  const { viewmodel, onFileNodeClick } = props
  const nodes = useStateValue(viewmodel.nodes$)
  useStateValue(viewmodel.forceRerenderTick$)

  const currentFilepath: string | null = useStateValue(viewmodel.currentFilepath$)

  const onNodeClick = useEventCallback((node: IFileTreeNode) => {
    if (node.type === 'file') {
      onFileNodeClick(node)
    }
  })

  return (
    <div className="text-sm">
      {nodes.map(node => (
        <FileTreeNode
          key={node.uuid}
          node={node}
          currentFilepath={currentFilepath}
          onNodeClick={onNodeClick}
        />
      ))}
    </div>
  )
}
