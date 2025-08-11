import React from 'react'
import { Composer } from './Composer'
import { SvgViewProvider } from './context'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string
  readonly mainScrollableContainer: HTMLDivElement | null
}

export const SvgView: React.FC<IProps> = props => {
  const { filepath, workspace, mainScrollableContainer } = props

  return (
    <SvgViewProvider workspace={workspace} filepath={filepath}>
      <Composer mainScrollableContainer={mainScrollableContainer} />
    </SvgViewProvider>
  )
}

SvgView.displayName = 'SvgView'
