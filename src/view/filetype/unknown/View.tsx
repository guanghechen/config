import React from 'react'
import { Composer } from './Composer'
import { UnknownViewProvider } from './context'

interface IProps {
  readonly filepath: string | null
  readonly extname: string
}

export const UnknownView: React.FC<IProps> = props => {
  const { filepath, extname } = props
  return (
    <UnknownViewProvider>
      <Composer filepath={filepath} extname={extname} />
    </UnknownViewProvider>
  )
}

UnknownView.displayName = 'UnknownView'
