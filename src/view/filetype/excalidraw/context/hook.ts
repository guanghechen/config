import type { ExcalidrawElement } from '@excalidraw/excalidraw/element/types'
import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import type { SiteTheme } from '@/context/site'
import { ExcalidrawViewContextType } from './context'
import type { ExcalidrawViewViewModel } from './viewmodel'

export const useExcalidrawViewViewModel = (): ExcalidrawViewViewModel => {
  const context = React.useContext(ExcalidrawViewContextType)
  return context.viewmodel
}

// Alias for backwards compatibility
export const useExcalidrawViewModel = useExcalidrawViewViewModel

export const useExcalidrawViewState = (): {
  elements: ReadonlyArray<ExcalidrawElement>
  content: string | null
  workspace: string | null
  filepath: string | null
  theme: SiteTheme | null
  error: string | null
} => {
  const viewmodel = useExcalidrawViewViewModel()
  const elements = useStateValue(viewmodel.elements$)
  const content = useStateValue(viewmodel.content$)
  const workspace = useStateValue(viewmodel.workspace$)
  const filepath = useStateValue(viewmodel.filepath$)
  const theme = useStateValue(viewmodel.theme$)
  const error = useStateValue(viewmodel.error$)

  return {
    elements,
    content,
    workspace,
    filepath,
    theme,
    error,
  }
}
