import React from 'react'
import { MarkdownViewContextType } from './context'
import { ModeEnum } from './types'
import { MarkdownViewViewModel } from './viewmodel'

interface IProps {
  readonly tocActivatedIdentifier?: string | null
  readonly specifiedTocActivatedIdentifier?: string | null
  readonly mode?: ModeEnum
  readonly children: React.ReactNode
}

export const MarkdownViewProvider: React.FC<IProps> = props => {
  const { tocActivatedIdentifier, specifiedTocActivatedIdentifier, mode, children } = props
  const [viewmodel] = React.useState<MarkdownViewViewModel>(
    () =>
      new MarkdownViewViewModel({ tocActivatedIdentifier, specifiedTocActivatedIdentifier, mode }),
  )
  const value = React.useMemo(() => ({ viewmodel }), [viewmodel])

  return (
    <MarkdownViewContextType.Provider value={value}>
      {children}
      <SideEffect
        viewmodel={viewmodel}
        tocActivatedIdentifier={tocActivatedIdentifier}
        specifiedTocActivatedIdentifier={specifiedTocActivatedIdentifier}
        mode={mode}
      />
    </MarkdownViewContextType.Provider>
  )
}

MarkdownViewProvider.displayName = 'MarkdownViewProvider'

// /////////////////////////////////////////////////////////////////////////////////////////////////

interface ISideEffectProps {
  readonly viewmodel: MarkdownViewViewModel
  readonly tocActivatedIdentifier?: string | null
  readonly specifiedTocActivatedIdentifier?: string | null
  readonly mode?: ModeEnum
}

const SideEffect: React.FC<ISideEffectProps> = props => {
  const { viewmodel, tocActivatedIdentifier, specifiedTocActivatedIdentifier, mode } = props

  React.useEffect(() => {
    viewmodel.tocActivatedIdentifier$.next(tocActivatedIdentifier ?? null)
  }, [viewmodel.tocActivatedIdentifier$, tocActivatedIdentifier])

  React.useEffect(() => {
    viewmodel.specifiedTocActivatedIdentifier$.next(specifiedTocActivatedIdentifier ?? null)
  }, [viewmodel.specifiedTocActivatedIdentifier$, specifiedTocActivatedIdentifier])

  React.useEffect(() => {
    viewmodel.mode$.next(mode ?? ModeEnum.VIEW)
  }, [viewmodel.mode$, mode])

  return <React.Fragment />
}

SideEffect.displayName = 'MarkdownViewSideEffect'
