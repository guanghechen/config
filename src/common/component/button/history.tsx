import cn from 'clsx'
import React from 'react'

interface IProps {
  readonly className?: string
  readonly disabled?: boolean
  readonly onClick: () => void
}

export class HistoryButton extends React.PureComponent<IProps> {
  public static readonly displayName: string = 'HistoryButton'

  public override render(): React.ReactElement {
    const { className, disabled, onClick } = this.props

    return (
      <button
        type="button"
        title="View history"
        disabled={disabled}
        onClick={onClick}
        className={cn(
          'flex items-center justify-center rounded-md text-xs font-medium',
          'p-1 bg-transparent border border-transparent transition-all duration-200',
          'text-gray-500 dark:text-gray-400 cursor-pointer',
          'hover:bg-gray-100 dark:hover:bg-white/10',
          'focus:outline-hidden focus:ring-2 focus:ring-blue-300/50',
          'disabled:opacity-50 disabled:cursor-default',
          className,
        )}
      >
        <svg
          width="14"
          height="14"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth="2"
          strokeLinecap="round"
          strokeLinejoin="round"
        >
          <circle cx="12" cy="12" r="10" />
          <polyline points="12,6 12,12 16,14" />
        </svg>
      </button>
    )
  }
}
