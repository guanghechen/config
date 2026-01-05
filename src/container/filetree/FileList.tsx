import { useEventCallback } from '@guanghechen/react-hooks'
import { useStateValue } from '@guanghechen/react-viewmodel'
import { useVirtualizer } from '@tanstack/react-virtual'
import React from 'react'
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

  const parentRef = React.useRef<HTMLDivElement>(null)

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

  const virtualizer = useVirtualizer({
    count: filteredNodes.length,
    getScrollElement: () => parentRef.current,
    estimateSize: () => 33,
    overscan: 5,
  })

  return (
    <div ref={parentRef} className="p-2 text-sm overflow-auto" style={{ height: '100%' }}>
      <div style={{ height: `${virtualizer.getTotalSize()}px`, position: 'relative' }}>
        {virtualizer.getVirtualItems().map(virtualItem => {
          const node = filteredNodes[virtualItem.index]

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
              <FileListItem
                node={node}
                currentFilepath={currentFilepath}
                searchKeyword={searchKeyword}
                onNodeClick={onNodeClick}
              />
            </div>
          )
        })}
      </div>
    </div>
  )
}
FileList.displayName = 'FileList'
