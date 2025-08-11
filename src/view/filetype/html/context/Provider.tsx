import React from 'react'
import { HtmlViewContextType } from './context'
import { HtmlViewViewModel } from './viewmodel'

interface IProps {
  readonly workspace?: string | null
  readonly filepath?: string | null
  readonly children: React.ReactNode
}

export const HtmlViewProvider: React.FC<IProps> = props => {
  const { workspace, filepath, children } = props
  const [viewmodel] = React.useState<HtmlViewViewModel>(
    () => new HtmlViewViewModel({ workspace, filepath }),
  )
  const value = React.useMemo(() => ({ viewmodel }), [viewmodel])

  return (
    <HtmlViewContextType.Provider value={value}>
      {children}
      <SideEffect viewmodel={viewmodel} workspace={workspace} filepath={filepath} />
    </HtmlViewContextType.Provider>
  )
}

HtmlViewProvider.displayName = 'HtmlViewProvider'

interface ISideEffectProps {
  readonly viewmodel: HtmlViewViewModel
  readonly workspace?: string | null
  readonly filepath?: string | null
}

const SideEffect: React.FC<ISideEffectProps> = props => {
  const { viewmodel, workspace, filepath } = props

  React.useEffect(() => {
    viewmodel.workspace$.next(workspace ?? null)
  }, [viewmodel.workspace$, workspace])

  React.useEffect(() => {
    viewmodel.filepath$.next(filepath ?? null)
  }, [viewmodel.filepath$, filepath])

  return <React.Fragment />
}

SideEffect.displayName = 'HtmlViewSideEffect'
