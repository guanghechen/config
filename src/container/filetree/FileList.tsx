import { useEventCallback } from '@guanghechen/react-hooks'
import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { VirtualList } from '@/common/component/virtual-list'
import type { FileTreeViewModel, IFileTreeFileNode, IFileTreeNode } from './context'
import { FileListItem } from './FileListItem'

interface IProps {
  readonly viewmodel: FileTreeViewModel
  readonly onFileNodeClick: (node: IFileTreeFileNode) => void
}

export const FileList: React.FC<IProps> = props => {
  const { viewmodel, onFileNodeClick } = props
  const fileNodes = useStateValue(viewmodel.fileNodes$)
  const currentFilepath: string | null = useStateValue(viewmodel.currentFilepath$)
  const searchKeyword: string = useStateValue(viewmodel.searchKeyword$)
  const nodeDataDirtyTick: number = useStateValue<number>(viewmodel.nodeDataDirtyTick$)

  const onNodeClick = useEventCallback((node: IFileTreeNode) => {
    switch (node.type) {
      case 'file':
        onFileNodeClick(node)
        break
      case 'folder':
        break
      default:
        console.error('Unknown node type:', node)
    }
  })

  const filteredNodes: IFileTreeFileNode[] = React.useMemo<IFileTreeFileNode[]>(() => {
    if (searchKeyword.length < 1) return fileNodes

    const keyword = searchKeyword.toLowerCase()
    return fileNodes.filter(node => node.filepath_lower.includes(keyword))
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [fileNodes, searchKeyword, nodeDataDirtyTick])

  return (
    <VirtualList
      className="p-2 text-sm"
      style={{ height: '100%' }}
      items={filteredNodes}
      itemHeight={33}
      overscan={5}
      getItemKey={node => node.uuid}
      renderItem={node => (
        <FileListItem
          node={node}
          currentFilepath={currentFilepath}
          searchKeyword={searchKeyword}
          onNodeClick={onNodeClick}
        />
      )}
    />
  )
}
FileList.displayName = 'FileList'
