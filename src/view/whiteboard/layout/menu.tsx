import { useStateValue } from '@guanghechen/react-viewmodel'
import cn from 'clsx'
import React from 'react'
import { useWhiteboardViewmodel } from '../context'

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
        <svg className="h-4 w-4" fill="currentColor" viewBox="0 0 24 24">
          <rect
            x="2"
            y="3"
            width="20"
            height="18"
            rx="2"
            fill="none"
            stroke="currentColor"
            strokeWidth="1.5"
          />
          <text x="12" y="9" textAnchor="middle" fontSize="4" fontWeight="bold" fill="currentColor">
            MD
          </text>
          <path
            d="M5 14h2l1.5-2 1.5 2h2"
            fill="none"
            stroke="currentColor"
            strokeWidth="1"
            strokeLinecap="round"
            strokeLinejoin="round"
          />
          <path
            d="M15 12h4m-2-1v2"
            fill="none"
            stroke="currentColor"
            strokeWidth="1"
            strokeLinecap="round"
            strokeLinejoin="round"
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

export const Menu: React.FC = () => {
  const viewmodel = useWhiteboardViewmodel()
  const contentData = useStateValue(viewmodel.contentData$)
  const editorVisible = useStateValue(viewmodel.editorVisible$)
  const filetype = useStateValue(viewmodel.filetype$)
  const filename = useStateValue(viewmodel.filename$)

  const [isSaveDropdownOpen, setIsSaveDropdownOpen] = React.useState(false)
  const [isFiletypeDropdownOpen, setIsFiletypeDropdownOpen] = React.useState(false)
  const saveDropdownRef = React.useRef<HTMLDivElement>(null)
  const filetypeDropdownRef = React.useRef<HTMLDivElement>(null)

  React.useEffect(() => {
    const handleClickOutside = (event: MouseEvent): void => {
      if (saveDropdownRef.current && !saveDropdownRef.current.contains(event.target as Node)) {
        setIsSaveDropdownOpen(false)
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
    setIsSaveDropdownOpen(false)
  }

  const handleSelectFile = (): void => {
    void viewmodel.selectFile()
    setIsSaveDropdownOpen(false)
  }

  const handleSaveFile = (): void => {
    void viewmodel.saveToFile()
    setIsSaveDropdownOpen(false)
  }

  const handleToggleEditor = (): void => {
    viewmodel.toggleEditor()
  }

  const handleFiletypeChange = (newFiletype: string): void => {
    viewmodel.updateFiletype(newFiletype)
    setIsFiletypeDropdownOpen(false)
  }

  // Define supported filetypes
  const SUPPORTED_FILETYPES = [
    { value: 'text', label: 'Text' },
    { value: 'markdown', label: 'Markdown' },
    { value: 'json', label: 'JSON' },
    { value: 'html', label: 'HTML' },
    { value: 'svg', label: 'SVG' },
    { value: 'excalidraw', label: 'Excalidraw' },
  ]

  // Get the display name for the current filetype
  const currentFiletypeLabel =
    SUPPORTED_FILETYPES.find(type => type.value === filetype)?.label || 'Editor'

  return (
    <div className="flex items-center space-x-2">
      {contentData.loading && (
        <div className="text-sm text-gray-500 dark:text-gray-400">Loading...</div>
      )}

      {contentData.contentError && (
        <div className="text-sm text-red-500 dark:text-red-400">{contentData.contentError}</div>
      )}

      {/* Editor Button with Filetype Dropdown */}
      <div className="relative" ref={filetypeDropdownRef}>
        <div className="flex">
          {/* Editor Toggle Button */}
          <button
            onClick={handleToggleEditor}
            className={cn(
              'group flex h-7 select-none items-center gap-2 rounded-l-lg px-2.5 py-1 text-sm font-medium shadow-sm backdrop-blur-sm transition-all duration-200 hover:shadow-lg focus:outline-none',
              editorVisible
                ? 'bg-indigo-100/80 text-indigo-700 hover:bg-indigo-200/80 dark:bg-indigo-900/80 dark:text-indigo-300 dark:hover:bg-indigo-800/80'
                : 'bg-white/80 text-gray-700 hover:bg-white/90 dark:bg-gray-900/80 dark:text-gray-300 dark:hover:bg-gray-900/90',
            )}
            aria-label="Toggle code editor"
            title={editorVisible ? 'Hide code editor' : 'Show code editor'}
          >
            <div
              className={cn(
                editorVisible
                  ? 'text-indigo-600 dark:text-indigo-400'
                  : 'text-gray-700 dark:text-gray-300',
              )}
            >
              {getFiletypeIcon(filetype)}
            </div>
            <span className="font-medium">{currentFiletypeLabel}</span>
          </button>

          {/* Filetype Dropdown Arrow Button */}
          <button
            onClick={() => setIsFiletypeDropdownOpen(!isFiletypeDropdownOpen)}
            className={cn(
              'group flex h-7 select-none items-center px-1.5 py-1 text-sm font-medium shadow-sm backdrop-blur-sm transition-all duration-200 hover:shadow-lg focus:outline-none border-l border-gray-200/50 dark:border-gray-700/50 rounded-r-lg',
              editorVisible
                ? 'bg-indigo-100/80 text-indigo-700 hover:bg-indigo-200/80 dark:bg-indigo-900/80 dark:text-indigo-300 dark:hover:bg-indigo-800/80'
                : 'bg-white/80 text-gray-700 hover:bg-white/90 dark:bg-gray-900/80 dark:text-gray-300 dark:hover:bg-gray-900/90',
            )}
            aria-expanded={isFiletypeDropdownOpen}
            aria-haspopup="menu"
            aria-label="Filetype options"
            title="Select filetype"
          >
            <svg
              className={cn(
                'h-3.5 w-3.5 transition-transform duration-200',
                editorVisible
                  ? 'text-indigo-500 dark:text-indigo-400'
                  : 'text-gray-500 dark:text-gray-400',
                isFiletypeDropdownOpen ? 'rotate-180' : '',
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
        </div>

        {isFiletypeDropdownOpen && (
          <div
            className="absolute z-50 right-0 top-full mt-1 min-w-40 overflow-hidden rounded-lg bg-white/95 shadow-xl backdrop-blur-md ring-1 ring-gray-200/50 dark:bg-gray-900/95 dark:ring-gray-700/50"
            role="menu"
            aria-label="Filetype options"
          >
            <div className="py-1">
              {SUPPORTED_FILETYPES.map(option => (
                <button
                  key={option.value}
                  onClick={() => handleFiletypeChange(option.value)}
                  className={cn(
                    'group flex w-full items-center gap-2.5 rounded-md px-2.5 py-1.5 text-left text-sm transition-all duration-150 focus:outline-none',
                    filetype === option.value
                      ? 'bg-indigo-50 text-indigo-700 shadow-sm dark:bg-indigo-900/50 dark:text-indigo-300'
                      : 'text-gray-700 hover:bg-gray-50 focus:bg-gray-50 dark:text-gray-300 dark:hover:bg-gray-800/50 dark:focus:bg-gray-800/50',
                  )}
                  role="menuitem"
                  tabIndex={isFiletypeDropdownOpen ? 0 : -1}
                >
                  <div
                    className={cn(
                      'flex h-4 w-4 items-center justify-center rounded transition-colors',
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
                      className="ml-auto h-3 w-3 text-indigo-600 dark:text-indigo-400"
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
      <div className="relative" ref={saveDropdownRef}>
        <div className="flex">
          {/* Save Toggle Button */}
          <button
            onClick={handleSaveFile}
            className="group flex h-7 select-none items-center gap-2 rounded-l-lg px-2.5 py-1 text-sm font-medium shadow-sm backdrop-blur-sm transition-all duration-200 hover:shadow-lg focus:outline-none bg-white/80 text-gray-700 hover:bg-white/90 dark:bg-gray-900/80 dark:text-gray-300 dark:hover:bg-gray-900/90"
            aria-label="Save file"
            title="Save file"
          >
            <div className="text-gray-700 dark:text-gray-300">
              <svg className="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M8 7H5a2 2 0 00-2 2v9a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-3m-1 4l-3 3m0 0l-3-3m3 3V4"
                />
              </svg>
            </div>
            <span className="font-medium">Save</span>
          </button>

          {/* Dropdown Arrow Button */}
          <button
            onClick={() => setIsSaveDropdownOpen(!isSaveDropdownOpen)}
            className="group flex h-7 select-none items-center px-1.5 py-1 text-sm font-medium shadow-sm backdrop-blur-sm transition-all duration-200 hover:shadow-lg focus:outline-none border-l border-gray-200/50 dark:border-gray-700/50 bg-white/80 text-gray-700 hover:bg-white/90 dark:bg-gray-900/80 dark:text-gray-300 dark:hover:bg-gray-900/90 rounded-r-lg"
            aria-expanded={isSaveDropdownOpen}
            aria-haspopup="menu"
            aria-label="Save options"
            title="Save options"
          >
            <svg
              className={cn(
                'h-3.5 w-3.5 transition-transform duration-200 text-gray-500 dark:text-gray-400',
                isSaveDropdownOpen ? 'rotate-180' : '',
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
        </div>

        {isSaveDropdownOpen && (
          <div
            className="absolute z-50 right-0 top-full mt-1 min-w-40 overflow-hidden rounded-lg bg-white/95 shadow-xl backdrop-blur-md ring-1 ring-gray-200/50 dark:bg-gray-900/95 dark:ring-gray-700/50"
            role="menu"
            aria-label="Save options"
          >
            <div className="py-1">
              <button
                onClick={handleSaveFile}
                className="group flex w-full items-center gap-2.5 rounded-md px-2.5 py-1.5 text-left text-sm transition-all duration-150 focus:outline-none text-gray-700 hover:bg-gray-50 focus:bg-gray-50 dark:text-gray-300 dark:hover:bg-gray-800/50 dark:focus:bg-gray-800/50"
                role="menuitem"
                tabIndex={isSaveDropdownOpen ? 0 : -1}
              >
                <div className="flex h-5 w-5 items-center justify-center rounded transition-colors text-gray-500 group-hover:text-gray-700 dark:text-gray-400 dark:group-hover:text-gray-300">
                  <svg className="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      strokeWidth={2}
                      d="M8 7H5a2 2 0 00-2 2v9a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-3m-1 4l-3 3m0 0l-3-3m3 3V4"
                    />
                  </svg>
                </div>
                <span className="font-medium">Save</span>
              </button>
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
                tabIndex={isSaveDropdownOpen && !contentData.loading ? 0 : -1}
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
                tabIndex={isSaveDropdownOpen && !contentData.loading ? 0 : -1}
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
      {filename && (
        <div className="text-sm text-gray-600 dark:text-gray-400 bg-gray-100/80 dark:bg-gray-800/80 px-2 py-1 rounded-md backdrop-blur-sm">
          {filename}
        </div>
      )}
    </div>
  )
}
Menu.displayName = 'WhiteboardViewMenu'
