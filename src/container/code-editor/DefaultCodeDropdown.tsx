import { useEventCallback } from '@guanghechen/react-hooks'
import React from 'react'
import { getDefaultCode } from '@/hook/api/code-default'
import { DEFAULT_CODE_TEMPLATE_OPTIONS } from './constant'

interface IProps {
  readonly onLoadTemplate: (content: string) => void
}

export const DefaultCodeDropdown: React.FC<IProps> = props => {
  const { onLoadTemplate } = props
  const [isOpen, setIsOpen] = React.useState(false)
  const [loading, setLoading] = React.useState<string | null>(null)

  const handleSelect = useEventCallback((filetype: string): void => {
    setIsOpen(false)
    setLoading(filetype)

    const loadTemplate = async (): Promise<void> => {
      try {
        const result = await getDefaultCode(filetype)
        if (result.error) {
          console.error('Failed to load template:', result.error)
          // You could show a toast notification here in the future
        } else if (result.content) {
          onLoadTemplate(result.content)
        }
      } catch (error) {
        console.error('Failed to load template:', error)
      } finally {
        setLoading(null)
      }
    }

    void loadTemplate()
  })

  return (
    <div className="relative">
      <button
        onClick={() => setIsOpen(!isOpen)}
        disabled={loading !== null}
        className="flex items-center gap-1.5 px-2 py-1 text-xs rounded border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-700 focus:outline-none focus:ring-1 focus:ring-blue-500 disabled:opacity-50 disabled:cursor-not-allowed"
      >
        {loading ? (
          <React.Fragment>
            <svg className="w-3 h-3 animate-spin" fill="none" viewBox="0 0 24 24">
              <circle
                className="opacity-25"
                cx="12"
                cy="12"
                r="10"
                stroke="currentColor"
                strokeWidth="4"
              />
              <path
                className="opacity-75"
                fill="currentColor"
                d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
              />
            </svg>
            <span>Loading...</span>
          </React.Fragment>
        ) : (
          <React.Fragment>
            <svg className="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
              />
            </svg>
            <span>Templates</span>
            <svg
              className={`w-3 h-3 transition-transform ${isOpen ? 'rotate-180' : ''}`}
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M19 9l-7 7-7-7"
              />
            </svg>
          </React.Fragment>
        )}
      </button>
      {isOpen && (
        <React.Fragment>
          <div className="absolute top-full right-0 mt-1 w-32 bg-white dark:bg-gray-800 rounded border border-gray-200 dark:border-gray-600 shadow-lg z-50 max-h-48 overflow-y-auto">
            {DEFAULT_CODE_TEMPLATE_OPTIONS.map(option => (
              <button
                key={option.value}
                onClick={() => handleSelect(option.value)}
                disabled={loading !== null}
                className="w-full text-left px-3 py-1.5 text-xs hover:bg-gray-100 dark:hover:bg-gray-700 text-gray-700 dark:text-gray-300 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {loading === option.value ? (
                  <div className="flex items-center gap-2">
                    <svg className="w-3 h-3 animate-spin" fill="none" viewBox="0 0 24 24">
                      <circle
                        className="opacity-25"
                        cx="12"
                        cy="12"
                        r="10"
                        stroke="currentColor"
                        strokeWidth="4"
                      />
                      <path
                        className="opacity-75"
                        fill="currentColor"
                        d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
                      />
                    </svg>
                    <span>Loading {option.label}...</span>
                  </div>
                ) : (
                  option.label
                )}
              </button>
            ))}
          </div>
          <div className="fixed inset-0 z-40" onClick={() => setIsOpen(false)} />
        </React.Fragment>
      )}
    </div>
  )
}

DefaultCodeDropdown.displayName = 'DefaultCodeDropdown'
