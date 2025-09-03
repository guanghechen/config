import React from 'react'
import { ViewLayout } from '@/container/ViewLayout'
import { FileSearch } from './container/FileSearch'
import { Main } from './layout/main'
import { Menu } from './layout/menu'
import { Setting } from './layout/setting'
import { Sidebar } from './layout/sidebar'

const storageKeyScope = '#/view/workspace'

export class Composer extends React.PureComponent {
  public static readonly displayName: string = 'WorkspaceViewComposer'

  public override render(): React.ReactElement {
    return (
      <ViewLayout
        scenario="workspace"
        floating={<FileSearch />}
        menu={<Menu />}
        sidebar={<Sidebar />}
        settings={<Setting />}
      >
        <Main storageKeyScope={storageKeyScope} />
      </ViewLayout>
    )
  }
}
