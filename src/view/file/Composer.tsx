import React from 'react'
import { ViewLayout } from '@/container/ViewLayout'
import { Main } from './layout/main'
import { Menu } from './layout/menu'

const storageKeyScope = '#/view/file'

export class Composer extends React.PureComponent {
  public static readonly displayName: string = 'FileViewComposer'

  public override render(): React.ReactElement {
    return (
      <ViewLayout scenario="file" menu={<Menu />}>
        <Main storageKeyScope={storageKeyScope} />
      </ViewLayout>
    )
  }
}
