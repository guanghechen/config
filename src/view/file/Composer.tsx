import React from 'react'
import { Main } from './layout/main'
import { Topbar } from './layout/topbar'

const storageKeyScope = '#/view/file'

export class Composer extends React.PureComponent {
  public static readonly displayName: string = 'FileViewComposer'

  public override render(): React.ReactElement {
    return (
      <div className="f-vf-root" data-view="file">
        <Topbar />
        <Main storageKeyScope={storageKeyScope} />
      </div>
    )
  }
}
