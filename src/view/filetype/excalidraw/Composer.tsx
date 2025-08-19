import React from 'react'
import { Main } from './layout/main'
import { Mode } from './layout/mode'

interface IProps {
  readonly filepath: string
  readonly workspace: string | null
}

export class Composer extends React.PureComponent<IProps> {
  public static readonly displayName: string = 'ExcalidrawViewComposer'

  public override render(): React.ReactElement {
    const { filepath, workspace } = this.props
    return (
      <React.Fragment>
        <Main filepath={filepath} workspace={workspace} />
        <Mode />
      </React.Fragment>
    )
  }
}
