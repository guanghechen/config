import React from 'react'
import { Main } from './layout/main'
import { ModeToggle } from './layout/mode'
import { Toolbar } from './layout/toolbar'

export class Composer extends React.PureComponent {
  public static readonly displayName: string = 'TextViewComposer'

  public override render(): React.ReactElement {
    return (
      <React.Fragment>
        <Main />
        <Toolbar />
        <ModeToggle />
      </React.Fragment>
    )
  }
}
