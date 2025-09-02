import React from 'react'
import { ViewLayout } from '@/container/ViewLayout'
import { Main } from './layout/main'
import { Topbar } from './layout/topbar'

const storageKeyScope = '#/view/file'

export class Composer extends React.PureComponent {
  public static readonly displayName: string = 'FileViewComposer'

  public override render(): React.ReactElement {
    return (
      <ViewLayout scenario="file" toolbar={<Topbar />}>
        <Main storageKeyScope={storageKeyScope} />
      </ViewLayout>
    )
  }
}
