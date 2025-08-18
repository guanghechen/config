import React from 'react'
import { TextViewProvider } from './context'
import './style.css'
import { Main } from './layout/main'
import { Topbar } from './layout/topbar'

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
        <Topbar filepath={filepath} />
        <Main />
      </TextViewProvider>
    )
  }
}
