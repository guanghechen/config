import React from 'react'
import type { WorkspaceViewModel } from '../context'
import { FileSearch } from './FileSearch'

interface IProps {
  readonly viewmodel: WorkspaceViewModel
}

export class WorkspaceFloat extends React.Component<IProps> {
  public static readonly displayName = 'WorkspaceFloat'

  public override render(): React.ReactElement {
    const { viewmodel } = this.props
    return (
      <React.Fragment>
        <FileSearch viewmodel={viewmodel} />
      </React.Fragment>
    )
  }
}

export default WorkspaceFloat
