import React from 'react'
import { Main } from './layout/main'
import { Mode } from './layout/mode'

export class Composer extends React.PureComponent {
  public static readonly displayName: string = 'SvgViewComposer'

  public override render(): React.ReactElement {
    return (
      <React.Fragment>
        <Main />
        <Mode />
      </React.Fragment>
    )
  }
}
