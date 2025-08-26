import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { useWhiteboardViewmodel } from './context'
import { Main } from './layout/main'
import { Sidebar } from './layout/sidebar'
import { Topbar } from './layout/topbar'

export const Composer: React.FC = () => {
  const viewmodel = useWhiteboardViewmodel()
  const editorVisible: boolean = useStateValue(viewmodel.editorVisible$)

  return (
    <div className="f-vf-root" data-view="whiteboard">
      <Topbar />
      <Main />
      <div className={editorVisible ? 'f-vf-editor' : 'hidden'}>
        <Sidebar />
      </div>
    </div>
  )
}

Composer.displayName = 'WhiteboardViewComposer'
