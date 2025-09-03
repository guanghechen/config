import React from 'react'
import { FiletreeToggler } from '../setting/filetree'
import { WorkspaceSelector } from '../setting/workspaces'

export class Setting extends React.PureComponent {
  public static readonly displayName = 'WorkspaceViewSetting'

  public override render(): React.ReactElement {
    return (
      <React.Fragment>
        <WorkspaceSelector />
        <FiletreeToggler />
      </React.Fragment>
    )
  }
}
