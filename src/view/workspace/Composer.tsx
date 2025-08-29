import React from 'react'
import { FileSearch } from './container/FileSearch'
import { Main } from './layout/main'
import { Sidebar } from './layout/sidebar'
import { Topbar } from './layout/topbar'

const storageKeyScope = '#/view/workspace'

export class Composer extends React.PureComponent {
  public static readonly displayName: string = 'WorkspaceViewComposer'

  public override render(): React.ReactElement {
    return (
      <div className="f-vf-root" data-view="workspace">
        <Topbar />
        <FileSearch />
        <div className="f-vf-sidebar">
          <Sidebar />
        </div>
        <Main storageKeyScope={storageKeyScope} />
      </div>
    )
  }
}
