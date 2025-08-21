import cn from 'clsx'
import React from 'react'
import { AnchorButton } from './button/anchor'
import { CopyButton } from './button/copy'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string
}

export class FilePath extends React.PureComponent<IProps> {
  public static readonly displayName: string = 'FilePath'

  public override render(): React.ReactElement {
    const { filepath } = this.props
    const { calcContentForCopy } = this

    const displayPath = filepath.length > 48 ? `...${filepath.slice(-48)}` : filepath
    const shouldShowTooltip = filepath.length > 48

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
      </div>
    )
  }

  protected calcContentForCopy = (): string => {
    return this.props.filepath
  }
}
