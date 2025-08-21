import React from 'react'
import { Composer } from './Composer'
import { JsonViewProvider } from './context'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string
  readonly filepathDirtyTick: number
}

export class JsonView extends React.PureComponent<IProps> {
  public static readonly displayName = 'JsonView'

  public override render(): React.ReactElement {
    const { workspace, filepath, filepathDirtyTick } = this.props

    return (
      <JsonViewProvider
        workspace={workspace}
        filepath={filepath}
        filepathDirtyTick={filepathDirtyTick}
      >
        <Composer />
      </JsonViewProvider>
    )
  }
}
