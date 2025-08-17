import React from 'react'
import { TotopButton } from '@/component/button/totop'
import { Composer } from './Composer'
import { JsonViewProvider } from './context'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string | null
  readonly filepathDirtyTick: number
  readonly mainScrollableContainer: HTMLDivElement | null
}

export class JsonView extends React.PureComponent<IProps> {
  public static readonly displayName = 'JsonView'

  public override render(): React.ReactElement {
    const { workspace, filepath, filepathDirtyTick, mainScrollableContainer } = this.props

    if (!filepath) {
      return (
        <div className="relative size-full flex items-center">
          <div className="text-center text-gray-500 dark:text-gray-400">No file specified</div>
        </div>
      )
    }

    return (
      <JsonViewProvider
        workspace={workspace}
        filepath={filepath}
        filepathDirtyTick={filepathDirtyTick}
      >
        <div className="relative size-full">
          <Composer />
          <TotopButton scrollableContainer={mainScrollableContainer} />
        </div>
      </JsonViewProvider>
    )
  }
}
