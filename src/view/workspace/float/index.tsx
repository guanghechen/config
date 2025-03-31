import React from 'react'
import type { WorkspaceViewModel } from '@/context/workspace'
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

  public override shouldComponentUpdate(nextProps: Readonly<IProps>): boolean {
    const props: IProps = this.props
    return props.viewmodel !== nextProps.viewmodel
  }
}

export default WorkspaceFloat
