import React from 'react'
import { FiletreeToggler } from '../setting/filetree'

export class Setting extends React.PureComponent {
  public static readonly displayName = 'WorkspaceViewSetting'

  public override render(): React.ReactElement {
    return (
      <React.Fragment>
        <FiletreeToggler />
      </React.Fragment>
    )
  }
}
