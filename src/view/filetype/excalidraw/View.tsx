import React from 'react'
import { Composer } from './Composer'
import { ExcalidrawViewProvider } from './context'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string | null
  readonly filepathDirtyTick: number
}

export class ExcalidrawView extends React.PureComponent<IProps> {
  public static readonly displayName = 'ExcalidrawView'

  public override render(): React.ReactElement {
    const { workspace, filepath, filepathDirtyTick } = this.props

    if (!filepath) {
      return (
        <div className="relative size-full flex items-center">
          <div className="text-center text-gray-500 dark:text-gray-400">No file specified</div>
        </div>
      )
    }

    return (
      <ExcalidrawViewProvider
        workspace={workspace}
        filepath={filepath}
        filepathDirtyTick={filepathDirtyTick}
      >
        <div className="relative size-full">
          <Composer />
        </div>
      </ExcalidrawViewProvider>
    )
  }
}
