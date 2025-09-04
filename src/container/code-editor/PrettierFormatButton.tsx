import cn from 'clsx'
import React from 'react'
import { usePrettier } from '@/hook/usePrettier'
import { isLanguageSupported } from '@/util/prettier'

interface IProps {
  readonly code: string
  readonly language: string
  readonly onFormatted: (formattedCode: string) => void
}

export const PrettierFormatButton: React.FC<IProps> = (props: IProps) => {
  const { code, language, onFormatted } = props
  const { isFormatting, formatWithNotifications } = usePrettier()

  const isSupported = isLanguageSupported(language)

  const handleFormat = React.useCallback(async () => {
    if (!code.trim() || !isSupported || isFormatting) return

    const result = await formatWithNotifications(code, language)

    if (result.success && result.formatted) {
      onFormatted(result.formatted)
    }
  }, [code, language, isSupported, isFormatting, formatWithNotifications, onFormatted])

  React.useEffect((): (() => void) => {
    const handleKeyDown = (event: KeyboardEvent): void => {
      if ((event.ctrlKey || event.metaKey) && event.shiftKey && event.key === 'F') {
        event.preventDefault()
        void handleFormat()
      }
    }

    document.addEventListener('keydown', handleKeyDown)
    return () => document.removeEventListener('keydown', handleKeyDown)
  }, [handleFormat])

  const buttonTitle = React.useMemo(() => {
    if (!isSupported) {
      return `Prettier formatting not available for ${language}`
    }
    if (isFormatting) return 'Formatting code...'
    if (!code.trim()) return 'No code to format'
    return 'Format code with Prettier (Ctrl+Shift+F)'
  }, [isSupported, isFormatting, code, language])

  const disabled = !isSupported || !code.trim() || isFormatting

  return (
    <div className="relative">
      <button
        onClick={() => void handleFormat()}
        disabled={disabled}
        title={buttonTitle}
        className={cn(
          'flex items-center gap-1 px-2 py-1 text-xs rounded transition-all duration-200',
          'focus:outline-none focus:ring-1 focus:ring-blue-500/50',
          disabled
            ? 'text-gray-400 dark:text-gray-600 cursor-not-allowed'
            : 'text-gray-600 dark:text-gray-400 hover:text-blue-600 dark:hover:text-blue-400 hover:bg-gray-100/50 dark:hover:bg-gray-700/50',
          isFormatting && 'animate-pulse',
        )}
      >
        <svg
          className={cn(
            'h-3 w-3 transition-transform duration-200',
            isFormatting && 'animate-spin',
          )}
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"
          />
        </svg>
        <span>{isFormatting ? 'Formatting...' : 'Format'}</span>
      </button>
    </div>
  )
}

PrettierFormatButton.displayName = 'PrettierFormatButton'
