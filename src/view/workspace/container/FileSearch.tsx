import { useEventCallback } from '@guanghechen/react-hooks'
import { useStateValue } from '@guanghechen/react-viewmodel'
import cn from 'clsx'
import React from 'react'
import { FileTypeIcon } from '@/component/icon/filetype'
import { useWorkspaceFiles } from '@/hook/useWorkspaceFiles'
import { useKeyBinding } from '@/keybindings'
import { useWorkspaceViewmodel } from '../context'

interface FileItem {
  filepath: string
  filepath_lower: string
  extname: string
}

export const FileSearch: React.FC = () => {
  const viewmodel = useWorkspaceViewmodel()
  const workspace = useStateValue(viewmodel.workspace$)
  const { files } = useWorkspaceFiles(workspace, 0)

  const [isVisible, setIsVisible] = React.useState(false)
  const [searchQuery, setSearchQuery] = React.useState('')
  const [currentFilepath, setCurrentFilepath] = React.useState<string | null>(null)
  const [fileList, setFileList] = React.useState<FileItem[]>([])
  const [filteredFileList, setFilteredFileList] = React.useState<FileItem[]>([])

  const inputRef = React.useRef<HTMLInputElement>(null)
  const containerRef = React.useRef<HTMLDivElement>(null)

  React.useEffect(() => {
    if (isVisible) {
      const newFileList = files.map(filepath => {
        const lastDotIndex = filepath.lastIndexOf('.')
        const extname = lastDotIndex >= 0 ? filepath.slice(lastDotIndex) : ''
        return {
          filepath,
          filepath_lower: filepath.toLowerCase(),
          extname,
        }
      })
      setFileList(newFileList)
    }
  }, [files, isVisible])

  React.useEffect(() => {
    if (searchQuery.length > 0) {
      const keyword = searchQuery.toLowerCase()
      const filtered = fileList.filter(file => file.filepath_lower.includes(keyword))
      setFilteredFileList(filtered)

      // Reset current selection to first item if available
      if (filtered.length > 0) {
        setCurrentFilepath(filtered[0].filepath)
      } else {
        setCurrentFilepath(null)
      }
    } else {
      setFilteredFileList(fileList)
      setCurrentFilepath(fileList.length > 0 ? fileList[0].filepath : null)
    }
  }, [fileList, searchQuery])

  const onKeyDown = useEventCallback((e: KeyboardEvent) => {
    // Handle search window navigation
    if (isVisible) {
      switch (e.key) {
        case 'Enter': {
          e.preventDefault()
          if (currentFilepath) onSelect(currentFilepath)
          return
        }
        case 'Escape': {
          onClose()
          return
        }
        case 'ArrowDown': {
          e.preventDefault()
          if (filteredFileList.length <= 0) return

          const idx = currentFilepath
            ? filteredFileList.findIndex(file => file.filepath === currentFilepath)
            : -1
          const nextIdx =
            idx < 0 ? 0 : idx + 1 >= filteredFileList.length ? filteredFileList.length - 1 : idx + 1
          setCurrentFilepath(filteredFileList[nextIdx].filepath)
          return
        }
        case 'ArrowUp': {
          e.preventDefault()
          if (filteredFileList.length <= 0) return

          const idx = currentFilepath
            ? filteredFileList.findIndex(file => file.filepath === currentFilepath)
            : -1
          const nextIdx =
            idx < 0
              ? filteredFileList.length - 1
              : idx === 0
                ? filteredFileList.length - 1
                : idx - 1
          setCurrentFilepath(filteredFileList[nextIdx].filepath)
          return
        }
        default:
      }
    }
  })

  const onClose = React.useCallback((): void => {
    setIsVisible(false)
    setSearchQuery('')
    setCurrentFilepath(null)
  }, [])

  const onSelect = useEventCallback((filepath: string) => {
    viewmodel.filepath$.next(filepath)
    onClose()
  })

  // Register Ctrl+; keybinding to open file search
  useKeyBinding({
    key: ';',
    ctrlKey: true,
    callback: (e: KeyboardEvent) => {
      e.preventDefault()
      setIsVisible(true)
      setTimeout(() => {
        inputRef.current?.focus()
      }, 10)
    },
    priority: 100,
  })

  React.useEffect(() => {
    if (!isVisible) return

    document.addEventListener('keydown', onKeyDown)
    return () => {
      document.removeEventListener('keydown', onKeyDown)
    }
  }, [onKeyDown, isVisible])

  // Close search when clicking outside
  React.useEffect(() => {
    const handleClickOutside = (e: MouseEvent): void => {
      if (isVisible && containerRef.current && !containerRef.current.contains(e.target as Node)) {
        onClose()
      }
    }

    document.addEventListener('mousedown', handleClickOutside)
    return () => {
      document.removeEventListener('mousedown', handleClickOutside)
    }
  }, [isVisible, onClose])

  if (!isVisible) return null

  return (
    <div
      ref={containerRef}
      className="fixed left-1/2 top-1/4 z-50 w-[48rem] max-w-[60vw] -translate-x-1/2 transform rounded-lg backdrop-blur-md backdrop-saturate-150 bg-white/30 border border-white/20 shadow-xl text-slate-800 dark:bg-gray-800/30 dark:border-gray-700/20 dark:text-gray-200"
    >
      <div className="p-2">
        <input
          ref={inputRef}
          type="text"
          value={searchQuery}
          onChange={e => setSearchQuery(e.target.value)}
          placeholder="Search files..."
          className="w-full rounded-md border border-gray-300/30 bg-transparent backdrop-blur-sm px-3 py-2 focus:outline-hidden focus:ring-2 focus:ring-blue-500/60 dark:border-gray-700/20 dark:text-gray-200"
          autoFocus={true}
        />
      </div>
      <div className="max-h-80 overflow-y-auto p-2 text-sm bg-white/20 dark:bg-gray-800/20 rounded-b-lg">
        {filteredFileList.map(file => (
          <div
            key={file.filepath}
            className={cn('select-none px-1 py-1 hover:bg-gray-200 dark:hover:bg-gray-700', {
              'bg-blue-100 text-blue-700 dark:bg-blue-900/50 dark:text-blue-300':
                file.filepath === currentFilepath,
            })}
            onClick={() => onSelect(file.filepath)}
          >
            <div className="flex cursor-pointer items-center">
              <span className="mr-1 flex-shrink-0">
                <FileTypeIcon extname={file.extname} />
              </span>
              <span className="truncate">
                {searchQuery.length > 0
                  ? highlightMatches(file.filepath, file.filepath_lower, searchQuery.toLowerCase())
                  : file.filepath}
              </span>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}

FileSearch.displayName = 'FileSearch'

const highlightMatches = (text: string, textLower: string, keyword: string): React.ReactNode[] => {
  const result: React.ReactNode[] = []

  let lastIndex = 0
  for (let index = textLower.indexOf(keyword, lastIndex); index !== -1; ) {
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
    index = textLower.indexOf(keyword, lastIndex)
  }

  if (lastIndex < text.length) {
    result.push(text.substring(lastIndex))
  }

  return result
}
