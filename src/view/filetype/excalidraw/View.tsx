import React from 'react'
import { Composer } from './Composer'
import { ExcalidrawViewProvider } from './context'
import './style.css'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string
  readonly filepathDirtyTick: number
}

export class ExcalidrawView extends React.PureComponent<IProps> {
  public static readonly displayName = 'ExcalidrawView'

  public override render(): React.ReactElement {
    const { workspace, filepath, filepathDirtyTick } = this.props

    return (
      <ExcalidrawViewProvider
        workspace={workspace}
        filepath={filepath}
        filepathDirtyTick={filepathDirtyTick}
      >
        <Composer />
      </ExcalidrawViewProvider>
    )
  }
}
