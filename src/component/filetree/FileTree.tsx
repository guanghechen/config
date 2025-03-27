import { useEventCallback } from '@guanghechen/react-hooks'
import { useStateValue } from '@guanghechen/react-viewmodel'
import cn from 'clsx'
import React from 'react'
import type {
  FileTreeViewModel,
  IFileTreeFileNode,
  IFileTreeFolderNodeMutable,
  IFileTreeNode,
} from './context'
import { FileTreeNode } from './FileTreeNode'

interface IProps {
  readonly viewmodel: FileTreeViewModel
  readonly onFileNodeClick: (node: IFileTreeFileNode) => void
}

export const FileTree: React.FC<IProps> = props => {
  const { viewmodel, onFileNodeClick } = props
  const root = useStateValue(viewmodel.root$)
  const currentFilepath: string | null = useStateValue(viewmodel.currentFilepath$)
  useStateValue(viewmodel.nodeDataDirtyTick$)

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

  const elements: React.ReactElement[] = React.useMemo<React.ReactElement[]>(() => {
    if (!root) return []

    const list: React.ReactElement[] = []

    inorderTraversal(root, false)
    return list

    function inorderTraversal(node: IFileTreeNode, parentCollapsed: boolean): void {
      const visible: boolean = !parentCollapsed
      const activate: boolean = node.type === 'file' && node.filepath === currentFilepath
      const collapsed: boolean = node.type === 'folder' && node.collapsed

      const element: React.ReactElement = (
        <div
          key={node.uuid}
          className={cn('select-none px-1 py-1 hover:bg-gray-200 dark:hover:bg-gray-700', {
            'bg-blue-100 text-blue-700 dark:bg-blue-900/50 dark:text-blue-300': activate,
            hidden: !visible,
          })}
          style={{ paddingLeft: `${node.depth * 12}px` }}
          onClick={() => onNodeClick(node)}
        >
          <FileTreeNode node={node} collapsed={collapsed} />
        </div>
      )
      list.push(element)

      if (node.type === 'folder') {
        const collapsed: boolean = parentCollapsed || node.collapsed
        for (const child of node.children) inorderTraversal(child, collapsed)
      }
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [root, viewmodel, currentFilepath, tick])

  return <div className="p-2 text-sm">{elements}</div>
}
FileTree.displayName = 'FileTree'
