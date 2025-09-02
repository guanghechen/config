import React from 'react'
import { ViewLayout } from '@/container/ViewLayout'
import { FileSearch } from './container/FileSearch'
import { Main } from './layout/main'
import { Sidebar } from './layout/sidebar'
import { Topbar } from './layout/topbar'

const storageKeyScope = '#/view/workspace'

export class Composer extends React.PureComponent {
  public static readonly displayName: string = 'WorkspaceViewComposer'

  public override render(): React.ReactElement {
    return (
      <ViewLayout
        scenario="workspace"
        floating={<FileSearch />}
        menu={<Topbar />}
        sidebar={<Sidebar />}
      >
        <Main storageKeyScope={storageKeyScope} />
      </ViewLayout>
    )
  }
}
