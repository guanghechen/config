import React from 'react'
import { Main } from './container/main'
import { Mode } from './container/mode'

interface IProps {
  readonly filepath: string
}

export const Composer: React.FC<IProps> = props => {
  const { filepath } = props
  return (
    <div className="box-border relative size-full">
      <div className="box-border fixed right-4 z-50 h-12">
        <Mode />
      </div>
      <div className="box-border size-full pt-12">
        <Main filepath={filepath} />
      </div>
    </div>
  )
}

Composer.displayName = 'UnknownViewComposer'
