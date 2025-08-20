import React from 'react'
import { Composer } from './Composer'
import { SvgViewProvider } from './context'
import './style.css'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string
  readonly filepathDirtyTick: number
}

export class SvgView extends React.PureComponent<IProps> {
  public static readonly displayName = 'SvgView'

  public override render(): React.ReactElement {
    const { filepath, workspace, filepathDirtyTick } = this.props

    return (
      <SvgViewProvider
        workspace={workspace}
        filepath={filepath}
        filepathDirtyTick={filepathDirtyTick}
      >
        <Composer />
      </SvgViewProvider>
    )
  }
}
