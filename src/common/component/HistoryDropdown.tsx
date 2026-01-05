import cn from 'clsx'
import React from 'react'

interface IProps {
  readonly history: string[]
  readonly currentFilepath: string | null
  readonly onSelect: (filepath: string) => void
}

export class HistoryDropdown extends React.PureComponent<IProps> {
  public static readonly displayName: string = 'HistoryDropdown'

  public override render(): React.ReactElement {
    const { history, currentFilepath } = this.props

    return (
      <div
        className={cn(
          'absolute top-full left-0 mt-1 z-50',
          'w-80 max-h-80 overflow-hidden',
          'bg-white dark:bg-gray-800 rounded-lg shadow-lg',
          'border border-gray-200 dark:border-gray-700',
        )}
      >
        <div className="px-3 py-2 border-b border-gray-200 dark:border-gray-700">
          <span className="text-xs font-medium text-gray-500 dark:text-gray-400">
            Recent Files ({history.length})
          </span>
        </div>
        <div className="overflow-y-auto max-h-64">
          {history.length === 0 ? (
            <div className="px-3 py-4 text-center text-xs text-gray-500 dark:text-gray-400">
              No recent files
            </div>
          ) : (
            <ul className="py-1">
              {history.map((filepath, index) => this.renderItem(filepath, index, currentFilepath))}
            </ul>
          )}
        </div>
      </div>
    )
  }

  protected renderItem = (
    filepath: string,
    index: number,
    currentFilepath: string | null,
  ): React.ReactElement => {
    const { onSelect } = this.props
    const isCurrent = filepath === currentFilepath
    const filename = filepath.split('/').pop() || filepath
    const directory = filepath.slice(0, filepath.length - filename.length - 1)

    const handleClick = (): void => {
      onSelect(filepath)
    }

    return (
      <li key={`${index}-${filepath}`}>
        <button
          type="button"
          onClick={handleClick}
          className={cn(
            'w-full px-3 py-1.5 text-left transition-colors',
            'hover:bg-gray-100 dark:hover:bg-gray-700',
            isCurrent && 'bg-blue-50 dark:bg-blue-900/30',
          )}
        >
          <div className="flex items-center gap-1.5">
            <span
              className={cn(
                'text-xs font-medium truncate',
                isCurrent ? 'text-blue-600 dark:text-blue-400' : 'text-gray-900 dark:text-gray-100',
              )}
            >
              {filename}
            </span>
            {isCurrent && (
              <span className="text-[10px] text-blue-500 dark:text-blue-400">(current)</span>
            )}
          </div>
          <div className="text-[10px] text-gray-500 dark:text-gray-400 truncate font-mono">
            {directory}
          </div>
        </button>
      </li>
    )
  }
}
