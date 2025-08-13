import React from 'react'
import { Composer } from './Composer'
import { SvgViewProvider } from './context'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string
  readonly filepathDirtyTick: number
  readonly mainScrollableContainer: HTMLDivElement | null
}

export const SvgView: React.FC<IProps> = props => {
  const { filepath, workspace, filepathDirtyTick, mainScrollableContainer } = props

  return (
    <SvgViewProvider
      workspace={workspace}
      filepath={filepath}
      filepathDirtyTick={filepathDirtyTick}
    >
      <Composer mainScrollableContainer={mainScrollableContainer} />
    </SvgViewProvider>
  )
}

SvgView.displayName = 'SvgView'
