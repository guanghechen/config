import React from 'react'
import { Main } from './layout/main'
import { Mode } from './layout/mode'
import { Toolbar } from './layout/toolbar'

export class Composer extends React.PureComponent {
  public static readonly displayName: string = 'PdfViewComposer'

  public override render(): React.ReactElement {
    return (
      <React.Fragment>
        <Main />
        <Toolbar />
        <Mode />
      </React.Fragment>
    )
  }
}
