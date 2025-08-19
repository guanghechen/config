import React from 'react'
import { FilePath } from '@/component/FilePath'

interface IProps {
  readonly filepath: string | null
}

export class Topbar extends React.PureComponent<IProps> {
  public static readonly displayName: string = 'FileViewTopbar'

  public override render(): React.ReactElement {
    const { filepath } = this.props

    return (
      <div className="f-vf-topbar">
        {filepath && <FilePath filepath={filepath} workspace={null} />}
      </div>
    )
  }
}
