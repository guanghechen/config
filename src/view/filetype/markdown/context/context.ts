import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import type { ModeEnum } from './types'
import { MarkdownViewViewModel } from './viewmodel'

export interface IMarkdownViewContext {
  readonly viewmodel: MarkdownViewViewModel
}

export const MarkdownViewContextType = React.createContext<IMarkdownViewContext>({
  viewmodel: new MarkdownViewViewModel(),
})

export const useMarkdownViewViewModel = (): MarkdownViewViewModel => {
  const context = React.useContext(MarkdownViewContextType)
  return context.viewmodel
}

// Alias for backwards compatibility
export const useMarkdownContext = useMarkdownViewViewModel

export const useMarkdownViewState = (): {
  tocActivatedIdentifier: string | null
  specifiedTocActivatedIdentifier: string | null
  mode: ModeEnum
} => {
  const viewmodel = useMarkdownViewViewModel()
  return {
    tocActivatedIdentifier: useStateValue(viewmodel.tocActivatedIdentifier$),
    specifiedTocActivatedIdentifier: useStateValue(viewmodel.specifiedTocActivatedIdentifier$),
    mode: useStateValue(viewmodel.mode$),
  }
}

// Alias for backwards compatibility
export const useMarkdownState = useMarkdownViewState

export const useMarkdownViewActions = (): {
  setTocActivatedIdentifier: (
    identifier: string | null | ((prev: string | null) => string | null),
  ) => void
  setSpecifiedTocActivatedIdentifier: (
    identifier: string | null | ((prev: string | null) => string | null),
  ) => void
  setMode: (mode: ModeEnum | ((prev: ModeEnum) => ModeEnum)) => void
} => {
  const viewmodel = useMarkdownViewViewModel()

  const setTocActivatedIdentifier = React.useCallback(
    (identifier: string | null | ((prev: string | null) => string | null)) => {
      const newIdentifier =
        typeof identifier === 'function'
          ? identifier(viewmodel.tocActivatedIdentifier$.getSnapshot())
          : identifier
      viewmodel.tocActivatedIdentifier$.next(newIdentifier)
    },
    [viewmodel],
  )

  const setSpecifiedTocActivatedIdentifier = React.useCallback(
    (identifier: string | null | ((prev: string | null) => string | null)) => {
      const newIdentifier =
        typeof identifier === 'function'
          ? identifier(viewmodel.specifiedTocActivatedIdentifier$.getSnapshot())
          : identifier
      viewmodel.specifiedTocActivatedIdentifier$.next(newIdentifier)
    },
    [viewmodel],
  )

  const setMode = React.useCallback(
    (mode: ModeEnum | ((prev: ModeEnum) => ModeEnum)) => {
      const newMode = typeof mode === 'function' ? mode(viewmodel.mode$.getSnapshot()) : mode
      viewmodel.mode$.next(newMode)
    },
    [viewmodel],
  )

  return {
    setTocActivatedIdentifier,
    setSpecifiedTocActivatedIdentifier,
    setMode,
  }
}

// Alias for backwards compatibility
export const useMarkdownActions = useMarkdownViewActions
