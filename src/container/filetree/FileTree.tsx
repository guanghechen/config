import { useEventCallback } from '@guanghechen/react-hooks'
import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { VirtualList } from '@/common/component/virtual-list'
import type {
  FileTreeViewModel,
  IFileTreeFileNode,
  IFileTreeFolderNodeMutable,
  IFileTreeNode,
} from './context'
import { FileTreeItem } from './FileTreeItem'

interface IProps {
  readonly viewmodel: FileTreeViewModel
  readonly onFileNodeClick: (node: IFileTreeFileNode) => void
}

interface IFlatNode {
  readonly node: IFileTreeNode
}

export const FileTree: React.FC<IProps> = props => {
  const { viewmodel, onFileNodeClick } = props
  const root = useStateValue(viewmodel.root$)
  const currentFilepath: string | null = useStateValue<string | null>(viewmodel.currentFilepath$)
  const nodeDataDirtyTick: number = useStateValue<number>(viewmodel.nodeDataDirtyTick$)

  const [tick, setTick] = React.useState<number>(0)

  const onNodeClick = useEventCallback((node: IFileTreeNode) => {
    switch (node.type) {
      case 'file':
        onFileNodeClick(node)
        break
      case 'folder': {
        const o = node as IFileTreeFolderNodeMutable
        o.collapsed = !o.collapsed
        setTick(tick => tick + 1)
        break
      }
      default:
        console.error('Unknown node type:', node)
    }
  })

  const flatNodes: IFlatNode[] = React.useMemo<IFlatNode[]>(() => {
    if (!root) return []

    const list: IFlatNode[] = []

    inorderTraversal(root, false)
    return list

    function inorderTraversal(node: IFileTreeNode, parentCollapsed: boolean): void {
      // 只将可见节点加入列表
      if (!parentCollapsed) {
        list.push({ node })
      }

      if (node.type === 'folder') {
        const collapsed: boolean = parentCollapsed || node.collapsed
        for (const child of node.children) inorderTraversal(child, collapsed)
      }
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [root, tick, nodeDataDirtyTick])

  return (
    <VirtualList
      className="p-2 text-sm"
      style={{ height: '100%' }}
      items={flatNodes}
      itemHeight={33}
      overscan={5}
      getItemKey={({ node }) => node.uuid}
      renderItem={({ node }) => (
        <FileTreeItem node={node} currentFilepath={currentFilepath} onNodeClick={onNodeClick} />
      )}
    />
  )
}
FileTree.displayName = 'FileTree'
