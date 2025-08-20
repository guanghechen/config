import React from 'react'
import { Main } from './layout/main'
import { Topbar } from './layout/topbar'

export const Composer: React.FC = () => {
  return (
    <div className="box-border relative size-full">
      <div className="box-border fixed right-4 z-50 h-12">
        <Topbar />
      </div>
      <div className="box-border size-full pt-12">
        <Main />
      </div>
    </div>
  )
}

Composer.displayName = 'ImageViewComposer'
