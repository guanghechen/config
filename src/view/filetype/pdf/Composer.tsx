import React from 'react'
import { Main } from './layout/main'
import { Mode } from './layout/mode'

interface IProps {
  readonly workspace: string | null
}

export class Composer extends React.PureComponent<IProps> {
  public static readonly displayName: string = 'PdfViewComposer'

  public override render(): React.ReactElement {
    const { workspace } = this.props
    return (
      <React.Fragment>
        <Main workspace={workspace} />
        <Mode />
      </React.Fragment>
    )
  }
}
