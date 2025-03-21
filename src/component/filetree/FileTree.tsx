import { useEventCallback } from '@guanghechen/react-hooks'
import { useStateValue } from '@guanghechen/react-viewmodel'
import cn from 'clsx'
import React from 'react'
import { FileTreeNode } from '@/component/filetree'
import type {
  FileTreeViewModel,
  IFileTreeFileNode,
  IFileTreeFolderNode,
  IFileTreeFolderNodeMutable,
  IFileTreeNode,
  IFileTreeNodeMap,
} from './context'

interface IProps {
  readonly viewmodel: FileTreeViewModel
  readonly onFileNodeClick: (node: IFileTreeFileNode) => void
}

export const FileTree: React.FC<IProps> = props => {
  const { viewmodel, onFileNodeClick } = props
  const root = useStateValue(viewmodel.root$)
  const currentFilepath: string | null = useStateValue(viewmodel.currentFilepath$)
  const searchKeyword: string = useStateValue(viewmodel.searchKeyword$)

  const [_, setTick] = React.useState<number>(0)
  const visibleUuidSet = React.useMemo(() => new Set<string>(), [])

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
    inorderTraversalBuild(root, false)
    return list

    function inorderTraversalBuild(node: IFileTreeNode, parentCollapsed: boolean): void {
      const activate: boolean = node.type === 'file' && node.filepath === currentFilepath
      const visible: boolean =
        !parentCollapsed && (searchKeyword.length === 0 || visibleUuidSet.has(node.uuid))

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
          <FileTreeNode node={node} />
        </div>
      )
      list.push(element)

      if (node.type === 'folder') {
        const collapsed: boolean = parentCollapsed || node.collapsed
        for (const child of node.children) inorderTraversalBuild(child, collapsed)
      }
    }
  }, [root, currentFilepath, onNodeClick, searchKeyword, visibleUuidSet])

  React.useEffect(() => {
    visibleUuidSet.clear()
    if (searchKeyword.length > 0) {
      const keyword: string = searchKeyword.toLowerCase()
      const nodeMap: IFileTreeNodeMap = viewmodel.nodeMap$.getSnapshot()
      for (const node of nodeMap.values()) {
        if (node.type !== 'file') continue
        if (!node.filepath.toLowerCase().includes(keyword)) continue

        visibleUuidSet.add(node.uuid)
        for (let parent: IFileTreeFolderNode | null = node.parent; parent; parent = parent.parent) {
          if (visibleUuidSet.has(parent.uuid)) break
          visibleUuidSet.add(parent.uuid)
        }
      }
    }
    setTick(tick => tick + 1)
  }, [viewmodel, searchKeyword, visibleUuidSet])

  return <div className="text-sm">{elements}</div>
}
