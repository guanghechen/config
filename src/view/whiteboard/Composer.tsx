import React from 'react'
import { Main } from './layout/main'
import { Topbar } from './layout/topbar'

export const Composer: React.FC = () => {
  return (
    <div className="h-screen flex flex-col">
      <Topbar />
      <Main />
    </div>
  )
}

Composer.displayName = 'WhiteboardViewComposer'
