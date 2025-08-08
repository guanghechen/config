import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { PdfViewContextType } from './context'
import type { PdfViewViewModel } from './viewmodel'

export const usePdfViewViewModel = (): PdfViewViewModel => {
  const context = React.useContext(PdfViewContextType)
  return context.viewmodel
}

// Alias for backwards compatibility
export const usePdfContext = usePdfViewViewModel

export const usePdfViewState = (): {
  workspace: string | null
  filepath: string
  currentPage: number
  numPages: number
  scale: number
} => {
  const viewmodel = usePdfViewViewModel()
  return {
    workspace: useStateValue(viewmodel.workspace$),
    filepath: useStateValue(viewmodel.filepath$),
    currentPage: useStateValue(viewmodel.pageno$),
    numPages: useStateValue(viewmodel.pages$),
    scale: useStateValue(viewmodel.scale$),
  }
}

// Alias for backwards compatibility
export const usePdfState = usePdfViewState

export const usePdfViewActions = (): {
  setCurrentPage: (page: number | ((prev: number) => number)) => void
  setNumPages: (pages: number | ((prev: number) => number)) => void
  setScale: (scale: number | ((prev: number) => number)) => void
} => {
  const viewmodel = usePdfViewViewModel()

  const setCurrentPage = React.useCallback(
    (page: number | ((prev: number) => number)) => {
      const newPage = typeof page === 'function' ? page(viewmodel.pageno$.getSnapshot()) : page
      viewmodel.pageno$.next(newPage)
    },
    [viewmodel],
  )

  const setNumPages = React.useCallback(
    (pages: number | ((prev: number) => number)) => {
      const newPages = typeof pages === 'function' ? pages(viewmodel.pages$.getSnapshot()) : pages
      viewmodel.pages$.next(newPages)
    },
    [viewmodel],
  )

  const setScale = React.useCallback(
    (scale: number | ((prev: number) => number)) => {
      const newScale = typeof scale === 'function' ? scale(viewmodel.scale$.getSnapshot()) : scale
      viewmodel.scale$.next(newScale)
    },
    [viewmodel],
  )

  return {
    setCurrentPage,
    setNumPages,
    setScale,
  }
}

// Alias for backwards compatibility
export const usePdfActions = usePdfViewActions
