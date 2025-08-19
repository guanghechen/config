import React from 'react'
import { FilePath } from '@/component/FilePath'
import { ModeToggle } from '../container/ModeToggle'

interface IProps {
  readonly filepath: string
  readonly workspace: string | null
}

export class Topbar extends React.PureComponent<IProps> {
  public static readonly displayName: string = 'JsonViewTopbar'

  public override render(): React.ReactElement {
    const { filepath, workspace } = this.props

    return (
      <div className="f-vf-topbar">
        <FilePath filepath={filepath} workspace={workspace} />
        <ModeToggle />
      </div>
    )
  }

  protected calcContentForCopy = (): string => {
    return this.props.filepath
  }
}
