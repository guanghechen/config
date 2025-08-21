import React from 'react'
import { Main } from './layout/main'
import { Mode } from './layout/mode'
import { Toolbar } from './layout/toolbar'

export const Composer: React.FC = () => {
  return (
    <React.Fragment>
      <Main />
      <Toolbar />
      <Mode />
    </React.Fragment>
  )
}

Composer.displayName = 'ImageViewComposer'
