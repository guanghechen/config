import type { ExcalidrawElement } from '@excalidraw/excalidraw/element/types'
import React from 'react'
import type { SiteTheme } from '@/context/site'
import { ExcalidrawViewContextType } from './context'
import { ExcalidrawViewViewModel } from './viewmodel'

interface IProps {
  readonly elements?: ReadonlyArray<ExcalidrawElement>
  readonly content?: string | null
  readonly workspace?: string | null
  readonly filepath?: string | null
  readonly theme?: SiteTheme
  readonly error?: string | null
  readonly children: React.ReactNode
}

export const ExcalidrawViewProvider: React.FC<IProps> = props => {
  const { elements, content, workspace, filepath, theme, error, children } = props
  const [viewmodel] = React.useState<ExcalidrawViewViewModel>(
    () => new ExcalidrawViewViewModel({ elements, content, workspace, filepath, theme, error }),
  )
  const value = React.useMemo(() => ({ viewmodel }), [viewmodel])

  return (
    <React.Fragment>
      <ExcalidrawViewContextType.Provider value={value}>
        {children}
      </ExcalidrawViewContextType.Provider>
      <SideEffect
        viewmodel={viewmodel}
        elements={elements}
        content={content}
        workspace={workspace}
        filepath={filepath}
        theme={theme}
        error={error}
      />
    </React.Fragment>
  )
}

ExcalidrawViewProvider.displayName = 'ExcalidrawViewProvider'

// /////////////////////////////////////////////////////////////////////////////////////////////////

interface ISideEffectProps {
  readonly viewmodel: ExcalidrawViewViewModel
  readonly elements?: ReadonlyArray<ExcalidrawElement>
  readonly content?: string | null
  readonly workspace?: string | null
  readonly filepath?: string | null
  readonly theme?: SiteTheme
  readonly error?: string | null
}

const SideEffect: React.FC<ISideEffectProps> = props => {
  const { viewmodel, elements, content, workspace, filepath, theme, error } = props

  React.useEffect(() => {
    viewmodel.elements$.next(elements ?? [])
  }, [viewmodel.elements$, elements])

  React.useEffect(() => {
    viewmodel.content$.next(content ?? null)
  }, [viewmodel.content$, content])

  React.useEffect(() => {
    viewmodel.workspace$.next(workspace ?? null)
  }, [viewmodel.workspace$, workspace])

  React.useEffect(() => {
    viewmodel.filepath$.next(filepath ?? null)
  }, [viewmodel.filepath$, filepath])

  React.useEffect(() => {
    viewmodel.theme$.next(theme ?? null)
  }, [viewmodel.theme$, theme])

  React.useEffect(() => {
    viewmodel.error$.next(error ?? null)
  }, [viewmodel.error$, error])

  return <React.Fragment />
}

SideEffect.displayName = 'ExcalidrawViewSideEffect'
