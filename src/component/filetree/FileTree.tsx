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

  const [tick, setTick] = React.useState<number>(0)

  const onNodeClick = useEventCallback((node: IFileTreeNode) => {
    switch (node.type) {
      case 'file':
        onFileNodeClick(node)
        break
      case 'folder': {
        if (searchKeyword.length > 0) return

        const o = node as IFileTreeFolderNodeMutable
        o.collapsed = !o.collapsed
        setTick(tick => tick + 1)
        break
      }
      default:
        console.error('Unknown node type:', node)
    }
  })

  const renderNode = React.useCallback(
    (
      node: IFileTreeNode,
      visible: boolean,
      activate: boolean,
      collapsed: boolean,
    ): React.ReactElement => {
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
      return element
    },
    [onNodeClick],
  )

  const elements: React.ReactElement[] = React.useMemo<React.ReactElement[]>(() => {
    if (!root) return []

    const list: React.ReactElement[] = []
    if (searchKeyword.length > 0) {
      const keyword = searchKeyword.toLowerCase()
      const uuids = new Set<string>()
      const nodeMap: IFileTreeNodeMap = viewmodel.nodeMap$.getSnapshot()
      for (const node of nodeMap.values()) {
        if (node.type !== 'file') continue
        if (!node.filepath_lower.includes(keyword)) continue

        uuids.add(node.uuid)
        for (let parent: IFileTreeFolderNode | null = node.parent; parent; parent = parent.parent) {
          if (uuids.has(parent.uuid)) break
          uuids.add(parent.uuid)
        }
      }
      inorderTraversalWithFilter(root)
      return list

      function inorderTraversalWithFilter(node: IFileTreeNode): void {
        const visible: boolean = uuids.has(node.uuid)
        const activate: boolean = node.type === 'file' && node.filepath === currentFilepath

        const element: React.ReactElement = renderNode(node, visible, activate, false)
        list.push(element)

        if (node.type === 'folder') {
          for (const child of node.children) inorderTraversalWithFilter(child)
        }
      }
    } else {
      inorderTraversal(root, false)
      return list

      function inorderTraversal(node: IFileTreeNode, parentCollapsed: boolean): void {
        const visible: boolean = !parentCollapsed
        const activate: boolean = node.type === 'file' && node.filepath === currentFilepath
        const collapsed: boolean = node.type === 'folder' && node.collapsed

        const element: React.ReactElement = renderNode(node, visible, activate, collapsed)
        list.push(element)

        if (node.type === 'folder') {
          const collapsed: boolean = parentCollapsed || node.collapsed
          for (const child of node.children) inorderTraversal(child, collapsed)
        }
      }
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [root, searchKeyword, viewmodel, currentFilepath, renderNode, tick])

  return <div className="text-sm">{elements}</div>
}
FileTree.displayName = 'FileTree'
