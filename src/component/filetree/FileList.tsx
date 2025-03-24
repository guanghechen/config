import { useEventCallback } from '@guanghechen/react-hooks'
import { useStateValue } from '@guanghechen/react-viewmodel'
import cn from 'clsx'
import React from 'react'
import { FileTypeIcon } from '../icon/filetype'
import type {
  FileTreeViewModel,
  IFileTreeFileNode,
  IFileTreeFolderNodeMutable,
  IFileTreeNode,
} from './context'

interface IProps {
  readonly viewmodel: FileTreeViewModel
  readonly onFileNodeClick: (node: IFileTreeFileNode) => void
}

export const FileList: React.FC<IProps> = props => {
  const { viewmodel, onFileNodeClick } = props
  const fileNodes = useStateValue(viewmodel.fileNodes$)
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

  const elements: React.ReactElement[] = React.useMemo<React.ReactElement[]>(() => {
    const keyword = searchKeyword.toLowerCase()
    const list: React.ReactElement[] = []
    for (const node of fileNodes) {
      const visible: boolean = searchKeyword.length < 1 || node.filepath_lower.includes(keyword)
      const activate: boolean = node.filepath === currentFilepath
      const element: React.ReactElement = (
        <div
          key={node.uuid}
          className={cn('select-none px-1 py-1 hover:bg-gray-200 dark:hover:bg-gray-700', {
            'bg-blue-100 text-blue-700 dark:bg-blue-900/50 dark:text-blue-300': activate,
            hidden: !visible,
          })}
          onClick={() => onNodeClick(node)}
        >
          <div className="flex cursor-pointer items-center">
            <span className="mr-1 flex-shrink-0">
              <FileTypeIcon extname={node.extname} />
            </span>
            <span className="truncate">
              {searchKeyword.length > 0
                ? highlightMatches(node.filepath_lower, keyword)
                : node.filepath}
            </span>
          </div>
        </div>
      )
      list.push(element)
    }

    return list
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [fileNodes, searchKeyword, viewmodel, currentFilepath, tick])

  return <div className="p-2 text-sm">{elements}</div>
}
FileList.displayName = 'FileList'

const highlightMatches = (text: string, keyword: string): React.ReactNode[] => {
  const result: React.ReactNode[] = []

  let lastIndex = 0
  for (let index = text.indexOf(keyword, lastIndex); index !== -1; ) {
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
