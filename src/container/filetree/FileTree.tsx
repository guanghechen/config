import { useEventCallback } from '@guanghechen/react-hooks'
import { useStateValue } from '@guanghechen/react-viewmodel'
import { useVirtualizer } from '@tanstack/react-virtual'
import React from 'react'
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
  const parentRef = React.useRef<HTMLDivElement>(null)

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

  const virtualizer = useVirtualizer({
    count: flatNodes.length,
    getScrollElement: () => parentRef.current,
    estimateSize: () => 33,
    overscan: 5,
  })

  return (
    <div ref={parentRef} className="p-2 text-sm overflow-auto" style={{ height: '100%' }}>
      <div style={{ height: `${virtualizer.getTotalSize()}px`, position: 'relative' }}>
        {virtualizer.getVirtualItems().map(virtualItem => {
          const { node } = flatNodes[virtualItem.index]

          return (
            <div
              key={node.uuid}
              style={{
                position: 'absolute',
                top: 0,
                left: 0,
                width: '100%',
                transform: `translateY(${virtualItem.start}px)`,
              }}
            >
              <FileTreeItem
                node={node}
                currentFilepath={currentFilepath}
                onNodeClick={onNodeClick}
              />
            </div>
          )
        })}
      </div>
    </div>
  )
}
FileTree.displayName = 'FileTree'
