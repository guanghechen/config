import { useStateValue } from '@guanghechen/react-viewmodel'
import cn from 'clsx'
import React from 'react'
import { useWhiteboardViewmodel } from '../context'

export const Topbar: React.FC = () => {
  const viewmodel = useWhiteboardViewmodel()
  const filetype = useStateValue(viewmodel.filetype$)
  const contentData = useStateValue(viewmodel.contentData$)

  const [isEditDropdownOpen, setIsEditDropdownOpen] = React.useState(false)
  const [isFiletypeDropdownOpen, setIsFiletypeDropdownOpen] = React.useState(false)
  const editDropdownRef = React.useRef<HTMLDivElement>(null)
  const filetypeDropdownRef = React.useRef<HTMLDivElement>(null)

  React.useEffect(() => {
    const handleClickOutside = (event: MouseEvent): void => {
      if (editDropdownRef.current && !editDropdownRef.current.contains(event.target as Node)) {
        setIsEditDropdownOpen(false)
      }
      if (
        filetypeDropdownRef.current &&
        !filetypeDropdownRef.current.contains(event.target as Node)
      ) {
        setIsFiletypeDropdownOpen(false)
      }
    }

    document.addEventListener('mousedown', handleClickOutside)
    return () => {
      document.removeEventListener('mousedown', handleClickOutside)
    }
  }, [])

  const handlePasteFromClipboard = (): void => {
    void viewmodel.pasteFromClipboard()
    setIsEditDropdownOpen(false)
  }

  const handleSelectFile = (): void => {
    viewmodel.selectFile()
    setIsEditDropdownOpen(false)
  }

  const getFiletypeIcon = (type: string): React.ReactNode => {
    switch (type) {
      case 'text':
        return (
          <svg className="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
            />
          </svg>
        )
      case 'markdown':
        return (
          <svg className="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M7 21h10a2 2 0 002-2V9.414a1 1 0 00-.293-.707l-5.414-5.414A1 1 0 0012.586 3H7a2 2 0 00-2 2v14a2 2 0 002 2z"
            />
          </svg>
        )
      case 'json':
        return (
          <svg className="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M8 9l3 3-3 3m5 0h3M5 20h14a2 2 0 002-2V6a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"
            />
          </svg>
        )
      case 'html':
        return (
          <svg className="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4"
            />
          </svg>
        )
      case 'svg':
        return (
          <svg className="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"
            />
          </svg>
        )
      case 'image':
        return (
          <svg className="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"
            />
          </svg>
        )
      case 'pdf':
        return (
          <svg className="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
            />
          </svg>
        )
      case 'excalidraw':
        return (
          <svg className="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z"
            />
          </svg>
        )
      default:
        return (
          <svg className="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
            />
          </svg>
        )
    }
  }

  const supportedFiletypes = [
    { value: 'text', label: 'Text' },
    { value: 'markdown', label: 'Markdown' },
    { value: 'json', label: 'JSON' },
    { value: 'html', label: 'HTML' },
    { value: 'svg', label: 'SVG' },
    { value: 'image', label: 'Image' },
    { value: 'pdf', label: 'PDF' },
    { value: 'excalidraw', label: 'Excalidraw' },
  ]

  const currentFiletype = supportedFiletypes.find(type => type.value === filetype)

  return (
    <div className="flex items-center justify-between px-2 h-12 bg-white dark:bg-gray-900">
      <div className="flex items-center space-x-2">
        {/* Whiteboard Icon */}
        <div className="text-gray-700 dark:text-gray-300" title="Whiteboard">
          <svg className="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M4 5a1 1 0 011-1h14a1 1 0 011 1v14a1 1 0 01-1 1H5a1 1 0 01-1-1V5zM16 3v4M8 3v4m5 4h.01M9 11h.01M15 11h.01M9 15h.01M15 15h.01"
            />
          </svg>
        </div>

        {contentData.loading && (
          <div className="text-sm text-gray-500 dark:text-gray-400">Loading...</div>
        )}

        {contentData.contentError && (
          <div className="text-sm text-red-500 dark:text-red-400">{contentData.contentError}</div>
        )}

        {/* Filetype Selector */}
        <div className="relative" ref={filetypeDropdownRef}>
          <button
            onClick={() => setIsFiletypeDropdownOpen(!isFiletypeDropdownOpen)}
            className="group flex h-7 select-none items-center gap-1.5 rounded-lg bg-white/80 px-2.5 py-1 text-sm font-medium shadow-sm backdrop-blur-sm transition-all duration-200 hover:bg-white/90 hover:shadow-lg focus:outline-none focus:ring-2 focus:ring-indigo-500/50 dark:bg-gray-900/80 dark:hover:bg-gray-900/90 dark:focus:ring-indigo-400/50"
            aria-expanded={isFiletypeDropdownOpen}
            aria-haspopup="listbox"
            aria-label={`Current filetype: ${currentFiletype?.label}`}
            title={`Filetype: ${currentFiletype?.label}`}
          >
            <div className="text-gray-700 dark:text-gray-300">{getFiletypeIcon(filetype)}</div>
            <span className="capitalize text-gray-700 dark:text-gray-300">
              {currentFiletype?.label}
            </span>
            <svg
              className={cn(
                'h-3.5 w-3.5 text-gray-500 transition-transform duration-200 dark:text-gray-400',
                isFiletypeDropdownOpen
                  ? 'rotate-180'
                  : 'group-hover:text-gray-700 dark:group-hover:text-gray-300',
              )}
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
              aria-hidden="true"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M19 9l-7 7-7-7"
              />
            </svg>
          </button>

          {isFiletypeDropdownOpen && (
            <div
              className="absolute z-50 left-0 top-full mt-1 min-w-40 overflow-hidden rounded-lg bg-white/95 shadow-xl backdrop-blur-md ring-1 ring-gray-200/50 dark:bg-gray-900/95 dark:ring-gray-700/50"
              role="listbox"
              aria-label="Filetype options"
            >
              <div className="py-1">
                {supportedFiletypes.map(option => (
                  <button
                    key={option.value}
                    onClick={() => {
                      viewmodel.updateFiletype(option.value)
                      setIsFiletypeDropdownOpen(false)
                    }}
                    className={cn(
                      'group flex w-full items-center gap-2.5 rounded-md px-2.5 py-1.5 text-left text-sm transition-all duration-150 focus:outline-none',
                      filetype === option.value
                        ? 'bg-indigo-50 text-indigo-700 shadow-sm dark:bg-indigo-900/50 dark:text-indigo-300'
                        : 'text-gray-700 hover:bg-gray-50 focus:bg-gray-50 dark:text-gray-300 dark:hover:bg-gray-800/50 dark:focus:bg-gray-800/50',
                    )}
                    role="option"
                    aria-selected={filetype === option.value}
                  >
                    <div
                      className={cn(
                        'flex h-5 w-5 items-center justify-center rounded transition-colors',
                        filetype === option.value
                          ? 'text-indigo-600 dark:text-indigo-400'
                          : 'text-gray-500 group-hover:text-gray-700 dark:text-gray-400 dark:group-hover:text-gray-300',
                      )}
                    >
                      {getFiletypeIcon(option.value)}
                    </div>
                    <span className="font-medium">{option.label}</span>
                    {filetype === option.value && (
                      <svg
                        className="ml-auto h-3.5 w-3.5 text-indigo-600 dark:text-indigo-400"
                        fill="currentColor"
                        viewBox="0 0 20 20"
                        aria-hidden="true"
                      >
                        <path
                          fillRule="evenodd"
                          d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z"
                          clipRule="evenodd"
                        />
                      </svg>
                    )}
                  </button>
                ))}
              </div>
            </div>
          )}
        </div>

        {/* Edit Dropdown */}
        <div className="relative" ref={editDropdownRef}>
          <button
            onClick={() => setIsEditDropdownOpen(!isEditDropdownOpen)}
            className="group flex h-7 select-none items-center gap-2 rounded-lg bg-white/80 px-2.5 py-1 text-sm font-medium shadow-sm backdrop-blur-sm transition-all duration-200 hover:bg-white/90 hover:shadow-lg focus:outline-none focus:ring-2 focus:ring-indigo-500/50 dark:bg-gray-900/80 dark:hover:bg-gray-900/90 dark:focus:ring-indigo-400/50"
            aria-expanded={isEditDropdownOpen}
            aria-haspopup="menu"
            aria-label="Edit content"
            title="Edit content"
          >
            <div className="text-gray-700 dark:text-gray-300">
              <svg className="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"
                />
              </svg>
            </div>
            <svg
              className={cn(
                'h-3.5 w-3.5 text-gray-500 transition-transform duration-200 dark:text-gray-400',
                isEditDropdownOpen
                  ? 'rotate-180'
                  : 'group-hover:text-gray-700 dark:group-hover:text-gray-300',
              )}
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
              aria-hidden="true"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M19 9l-7 7-7-7"
              />
            </svg>
          </button>

          {isEditDropdownOpen && (
            <div
              className="absolute z-50 left-0 top-full mt-1 min-w-40 overflow-hidden rounded-lg bg-white/95 shadow-xl backdrop-blur-md ring-1 ring-gray-200/50 dark:bg-gray-900/95 dark:ring-gray-700/50"
              role="menu"
              aria-label="Edit options"
            >
              <div className="py-1">
                <button
                  onClick={handlePasteFromClipboard}
                  disabled={contentData.loading}
                  className={cn(
                    'group flex w-full items-center gap-2.5 rounded-md px-2.5 py-1.5 text-left text-sm transition-all duration-150 focus:outline-none',
                    contentData.loading
                      ? 'cursor-not-allowed opacity-50'
                      : 'text-gray-700 hover:bg-gray-50 focus:bg-gray-50 dark:text-gray-300 dark:hover:bg-gray-800/50 dark:focus:bg-gray-800/50',
                  )}
                  role="menuitem"
                  tabIndex={isEditDropdownOpen && !contentData.loading ? 0 : -1}
                >
                  <div className="flex h-5 w-5 items-center justify-center rounded transition-colors text-gray-500 group-hover:text-gray-700 dark:text-gray-400 dark:group-hover:text-gray-300">
                    <svg className="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        strokeWidth={2}
                        d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"
                      />
                    </svg>
                  </div>
                  <span className="font-medium">Clipboard</span>
                </button>
                <button
                  onClick={handleSelectFile}
                  disabled={contentData.loading}
                  className={cn(
                    'group flex w-full items-center gap-2.5 rounded-md px-2.5 py-1.5 text-left text-sm transition-all duration-150 focus:outline-none',
                    contentData.loading
                      ? 'cursor-not-allowed opacity-50'
                      : 'text-gray-700 hover:bg-gray-50 focus:bg-gray-50 dark:text-gray-300 dark:hover:bg-gray-800/50 dark:focus:bg-gray-800/50',
                  )}
                  role="menuitem"
                  tabIndex={isEditDropdownOpen && !contentData.loading ? 0 : -1}
                >
                  <div className="flex h-5 w-5 items-center justify-center rounded transition-colors text-gray-500 group-hover:text-gray-700 dark:text-gray-400 dark:group-hover:text-gray-300">
                    <svg className="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        strokeWidth={2}
                        d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
                      />
                    </svg>
                  </div>
                  <span className="font-medium">Select File</span>
                </button>
              </div>
            </div>
          )}
        </div>
      </div>

      {/* Right side kept empty for filetype-specific widgets */}
      <div className="flex items-center space-x-2">
        {/* Empty - reserved for filetype-specific widgets */}
      </div>
    </div>
  )
}
