import React from 'react'
import { Composer } from './Composer'
import { HtmlViewProvider } from './context'
import './style.css'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string
  readonly filepathDirtyTick: number
}

export class HtmlView extends React.PureComponent<IProps> {
  public static readonly displayName = 'HtmlView'

  public override render(): React.ReactElement {
    const { filepath, workspace, filepathDirtyTick } = this.props

    return (
      <HtmlViewProvider
        workspace={workspace}
        filepath={filepath}
        filepathDirtyTick={filepathDirtyTick}
      >
        <Composer workspace={workspace} />
      </HtmlViewProvider>
    )
  }
}
