import React from 'react'
import { HtmlViewContextType } from './context'
import { HtmlViewViewModel } from './viewmodel'

interface IProps {
  readonly workspace?: string | null
  readonly filepath?: string | null
  readonly tailwindEnabled?: boolean
  readonly children: React.ReactNode
}

export const HtmlViewProvider: React.FC<IProps> = props => {
  const { workspace, filepath, tailwindEnabled, children } = props
  const [viewmodel] = React.useState<HtmlViewViewModel>(
    () => new HtmlViewViewModel({ workspace, filepath, tailwindEnabled }),
  )
  const value = React.useMemo(() => ({ viewmodel }), [viewmodel])

  return (
    <HtmlViewContextType.Provider value={value}>
      {children}
      <SideEffect
        viewmodel={viewmodel}
        workspace={workspace}
        filepath={filepath}
        tailwindEnabled={tailwindEnabled}
      />
    </HtmlViewContextType.Provider>
  )
}

HtmlViewProvider.displayName = 'HtmlViewProvider'

// /////////////////////////////////////////////////////////////////////////////////////////////////

interface ISideEffectProps {
  readonly viewmodel: HtmlViewViewModel
  readonly workspace?: string | null
  readonly filepath?: string | null
  readonly tailwindEnabled?: boolean
}

const SideEffect: React.FC<ISideEffectProps> = props => {
  const { viewmodel, workspace, filepath, tailwindEnabled } = props

  React.useEffect(() => {
    viewmodel.workspace$.next(workspace ?? null)
  }, [viewmodel.workspace$, workspace])

  React.useEffect(() => {
    viewmodel.filepath$.next(filepath ?? null)
  }, [viewmodel.filepath$, filepath])

  React.useEffect(() => {
    viewmodel.tailwindEnabled$.next(tailwindEnabled ?? false)
  }, [viewmodel.tailwindEnabled$, tailwindEnabled])

  return <React.Fragment />
}

SideEffect.displayName = 'HtmlViewSideEffect'
