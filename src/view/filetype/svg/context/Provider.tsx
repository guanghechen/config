import React from 'react'
import type { ISvgViewContext } from './context'
import { SvgViewContextType } from './context'
import { SvgViewViewModel } from './viewmodel'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string
  readonly children: React.ReactNode
}

export const SvgViewProvider: React.FC<IProps> = props => {
  const { workspace, filepath, children } = props
  const [viewmodel] = React.useState(
    () =>
      new SvgViewViewModel({
        workspace,
        filepath,
      }),
  )

  const context: ISvgViewContext = React.useMemo<ISvgViewContext>(
    () => ({ viewmodel }),
    [viewmodel],
  )

  return <SvgViewContextType.Provider value={context}>{children}</SvgViewContextType.Provider>
}

SvgViewProvider.displayName = 'SvgViewProvider'
