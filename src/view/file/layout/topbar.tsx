import cn from 'clsx'
import React from 'react'
import { AnchorButton } from '@/component/button/anchor'
import { CopyButton } from '@/component/button/copy'

interface IProps {
  readonly filepath: string | null
}

export class Topbar extends React.PureComponent<IProps> {
  public static readonly displayName: string = 'FileComposer'

  public override render(): React.ReactElement {
    const { filepath } = this.props

    if (!filepath) {
      return <React.Fragment />
    }

    return (
      <div className="flex items-center gap-1 h-full p-4">
        <h2 className="px-2 pointer-events-none select-none truncate font-mono text-sm font-medium text-gray-700 dark:text-gray-300">
          {filepath}
        </h2>
        <CopyButton
          className={cn(
            'rounded-lg text-gray-600 hover:text-gray-900 hover:bg-gray-100',
            'dark:text-gray-400 dark:hover:text-gray-100 dark:hover:bg-gray-700',
            'focus:outline-hidden focus:ring-2 focus:ring-blue-500 focus:ring-opacity-50 transition-colors',
          )}
          calcContentForCopy={() => filepath || ''}
        />
        <AnchorButton workspace={null} filepath={filepath} />
      </div>
    )
  }
}
