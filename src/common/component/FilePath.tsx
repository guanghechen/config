import cn from 'clsx'
import React from 'react'
import { AnchorButton } from './button/anchor'
import { CopyButton } from './button/copy'
import { HistoryButton } from './button/history'
import { HistoryDropdown } from './HistoryDropdown'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string
  readonly history?: string[]
  readonly onHistorySelect?: (filepath: string) => void
}

interface IState {
  readonly showHistory: boolean
}

export class FilePath extends React.PureComponent<IProps, IState> {
  public static readonly displayName: string = 'FilePath'

  constructor(props: IProps) {
    super(props)
    this.state = { showHistory: false }
  }

  public override render(): React.ReactElement {
    const { filepath, history, onHistorySelect } = this.props
    const { showHistory } = this.state
    const { calcContentForCopy } = this

    const displayPath = filepath.length > 48 ? `...${filepath.slice(-48)}` : filepath
    const shouldShowTooltip = filepath.length > 48
    const hasHistory = history && history.length > 0

    return (
      <div className="flex items-center gap-2">
        <h2
          className={cn(
            'px-2 select-none truncate font-mono text-sm font-medium text-gray-700 dark:text-gray-300',
            shouldShowTooltip ? 'cursor-help' : 'pointer-events-none',
          )}
          title={shouldShowTooltip ? filepath : undefined}
        >
          {displayPath}
        </h2>
        <CopyButton
          className={cn(
            'rounded-lg text-gray-600 hover:text-gray-900 hover:bg-gray-100',
            'dark:text-gray-400 dark:hover:text-gray-100 dark:hover:bg-gray-700',
            'focus:outline-hidden focus:ring-2 focus:ring-blue-500 focus:ring-opacity-50 transition-colors',
          )}
          calcContentForCopy={calcContentForCopy}
        />
        <AnchorButton workspace={null} filepath={filepath} />
        {onHistorySelect && (
          <div className="relative">
            <HistoryButton onClick={this.handleHistoryClick} disabled={!hasHistory} />
            {showHistory && hasHistory && (
              <HistoryDropdown
                history={history}
                currentFilepath={filepath}
                onSelect={this.handleHistorySelect}
              />
            )}
          </div>
        )}
        <span className="vl-fp-actions" />
      </div>
    )
  }

  protected handleHistoryClick = (): void => {
    this.setState(prev => ({ showHistory: !prev.showHistory }))
  }

  protected handleHistorySelect = (filepath: string): void => {
    this.props.onHistorySelect?.(filepath)
    this.setState({ showHistory: false })
  }

  protected calcContentForCopy = (): string => {
    return this.props.filepath
  }
}
