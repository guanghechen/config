import React from 'react'
import { Main } from './container/main'
import { Mode } from './container/mode'

export const Composer: React.FC = () => {
  return (
    <div className="box-border relative size-full">
      <div className="box-border fixed right-4 z-50 h-12">
        <Mode />
      </div>
      <div className="box-border size-full pt-12">
        <Main />
      </div>
    </div>
  )
}

Composer.displayName = 'UnknownViewComposer'
