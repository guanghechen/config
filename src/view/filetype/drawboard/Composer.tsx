import React from 'react'
import { Main } from './layout/main'
import { Mode } from './layout/mode'

interface IProps {
  readonly hideMode?: boolean
}

export class Composer extends React.PureComponent<IProps> {
  public static readonly displayName: string = 'DrawboardViewComposer'

  public override render(): React.ReactElement {
    const { hideMode } = this.props

    return (
      <React.Fragment>
        <Main />
        {!hideMode && <Mode />}
      </React.Fragment>
    )
  }
}
