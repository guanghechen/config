import React from 'react'
import { Composer } from './Composer'
import { TextViewProvider } from './context'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string
  readonly filepathDirtyTick: number
}

export class TextView extends React.PureComponent<IProps> {
  public static readonly displayName = 'TextView'

  public override render(): React.ReactElement {
    const { filepath, workspace, filepathDirtyTick } = this.props

    return (
      <TextViewProvider
        workspace={workspace}
        filepath={filepath}
        filepathDirtyTick={filepathDirtyTick}
      >
        <Composer />
      </TextViewProvider>
    )
  }
}
