import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { JsonViewContextType } from './context'
import type { ModeEnum } from './types'
import type { JsonViewViewModel } from './viewmodel'

export const useJsonViewViewModel = (): JsonViewViewModel => {
  const context = React.useContext(JsonViewContextType)
  return context.viewmodel
}

// Alias for backwards compatibility
export const useJsonContext = useJsonViewViewModel

export const useJsonViewState = (): {
  mode: ModeEnum
  content: string | null
} => {
  const viewmodel = useJsonViewViewModel()
  const mode = useStateValue(viewmodel.mode$)
  const content = useStateValue(viewmodel.content$)

  return {
    mode,
    content,
  }
}

// Alias for backwards compatibility
export const useJsonState = useJsonViewState

export const useJsonViewActions = (): {
  setMode: (mode: ModeEnum | ((prev: ModeEnum) => ModeEnum)) => void
  setContent: (content: string | null | ((prev: string | null) => string | null)) => void
} => {
  const viewmodel = useJsonViewViewModel()

  const setMode = React.useCallback(
    (mode: ModeEnum | ((prev: ModeEnum) => ModeEnum)) => {
      const newMode = typeof mode === 'function' ? mode(viewmodel.mode$.getSnapshot()) : mode
      viewmodel.mode$.next(newMode)
    },
    [viewmodel],
  )

  const setContent = React.useCallback(
    (content: string | null | ((prev: string | null) => string | null)) => {
      const newContent =
        typeof content === 'function' ? content(viewmodel.content$.getSnapshot()) : content
      viewmodel.content$.next(newContent)
    },
    [viewmodel],
  )

  return {
    setMode,
    setContent,
  }
}

// Alias for backwards compatibility
export const useJsonActions = useJsonViewActions
