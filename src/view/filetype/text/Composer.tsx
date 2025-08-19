import React from 'react'
import { Main } from './layout/main'
import { Topbar } from './layout/topbar'

interface IProps {
  readonly filepath: string
  readonly workspace: string | null
}

export class Composer extends React.PureComponent<IProps> {
  public static readonly displayName: string = 'TextViewComposer'

  public override render(): React.ReactElement {
    const { filepath, workspace } = this.props

    return (
      <div className="f-vf-root" data-filetype="text">
        <Topbar filepath={filepath} workspace={workspace} />
        <Main />
      </div>
    )
  }
}
