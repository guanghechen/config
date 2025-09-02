import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { ViewLayout } from '@/container/ViewLayout'
import { useWhiteboardViewmodel } from './context'
import { Main } from './layout/main'
import { Sidebar } from './layout/sidebar'
import { Topbar } from './layout/topbar'

export const Composer: React.FC = () => {
  const viewmodel = useWhiteboardViewmodel()
  const editorVisible: boolean = useStateValue(viewmodel.editorVisible$)

  return (
    <ViewLayout
      scenario="whiteboard"
      toolbar={<Topbar />}
      sidebar={editorVisible ? <Sidebar /> : undefined}
    >
      <Main />
    </ViewLayout>
  )
}

Composer.displayName = 'WhiteboardViewComposer'
