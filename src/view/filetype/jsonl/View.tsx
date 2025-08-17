import React from 'react'
import { TotopButton } from '@/component/button/totop'
import { Composer } from './Composer'
import { JsonlViewProvider } from './context'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string
  readonly filepathDirtyTick: number
  readonly mainScrollableContainer: HTMLDivElement | null
}

export class JsonlView extends React.PureComponent<IProps> {
  public static readonly displayName = 'JsonlView'

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
      <JsonlViewProvider
        workspace={workspace}
        filepath={filepath}
        filepathDirtyTick={filepathDirtyTick}
      >
        <div className="relative size-full">
          <Composer />
          <TotopButton scrollableContainer={mainScrollableContainer} />
        </div>
      </JsonlViewProvider>
    )
  }
}
