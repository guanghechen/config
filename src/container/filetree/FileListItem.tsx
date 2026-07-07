import cn from 'clsx'
import React from 'react'
import { FileTypeIcon } from '@/common/component/icon/filetype'
import type { IFileTreeFileNode, IFileTreeNode } from './context'

interface IProps {
  readonly node: IFileTreeFileNode
  readonly currentFilepath: string | null
  readonly searchKeyword: string
  readonly onNodeClick: (node: IFileTreeNode) => void
}

const FileListItemComponent: React.FC<IProps> = props => {
  const { node, currentFilepath, searchKeyword, onNodeClick } = props

  const activate: boolean = node.filepath === currentFilepath

  return (
    <div
      className={cn('select-none px-1 py-1 hover:bg-gray-200 dark:hover:bg-gray-600', {
        'bg-gray-300 text-gray-800 dark:bg-gray-500 dark:text-gray-100': activate,
      })}
      onClick={() => onNodeClick(node)}
    >
      <div className="flex cursor-pointer items-center">
        <span className="mr-1 flex-shrink-0">
          <FileTypeIcon extname={node.extname} />
        </span>
        <span className="truncate">
          {searchKeyword.length > 0
            ? highlightMatches(node.filepath_lower, searchKeyword.toLowerCase())
            : node.filepath}
        </span>
      </div>
    </div>
  )
}

export const FileListItem = React.memo(
  FileListItemComponent,
  (prevProps, nextProps) =>
    prevProps.node === nextProps.node &&
    prevProps.currentFilepath === nextProps.currentFilepath &&
    prevProps.searchKeyword === nextProps.searchKeyword &&
    prevProps.onNodeClick === nextProps.onNodeClick,
)
FileListItem.displayName = 'FileListItem'

const highlightMatches = (text: string, keyword: string): React.ReactNode[] => {
  const result: React.ReactNode[] = []

  let lastIndex = 0
  for (let index = text.indexOf(keyword, lastIndex); index !== -1;) {
    if (index > lastIndex) {
      result.push(text.substring(lastIndex, index))
    }

    result.push(
      <span
        key={`highlight-${index}`}
        className="rounded-sm bg-yellow-200 text-gray-900 dark:bg-yellow-700 dark:text-gray-100"
      >
        {text.substring(index, index + keyword.length)}
      </span>,
    )

    lastIndex = index + keyword.length
    index = text.indexOf(keyword, lastIndex)
  }

  if (lastIndex < text.length) {
    result.push(text.substring(lastIndex))
  }

  return result
}
