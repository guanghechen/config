import React from 'react'
import { Composer } from './Composer'
import { SvgViewProvider } from './context/Provider'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string
  readonly mainScrollableContainer: HTMLDivElement | null
}

export const SVGView: React.FC<IProps> = props => {
  const { filepath, workspace, mainScrollableContainer } = props

  return (
    <SvgViewProvider workspace={workspace} filepath={filepath}>
      <Composer mainScrollableContainer={mainScrollableContainer} />
    </SvgViewProvider>
  )
}

SVGView.displayName = 'SVGView'

export default SVGView
