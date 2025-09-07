import React from 'react'
import type { GridViewModel } from './viewmodel/grid'
import type { HistoryViewModel } from './viewmodel/history'
import type { LayersViewModel } from './viewmodel/layers'
import type { UIViewModel } from './viewmodel/ui'

// Composite viewmodel interface that provides a unified API
export interface IDrawboardCompositeViewModel {
  // Combined methods that work across multiple viewmodels
  undo: () => void
  redo: () => void
  canUndo: () => boolean
  canRedo: () => boolean
  saveToHistory: () => void
}

export interface IDrawboardContext {
  readonly grid: GridViewModel
  readonly layers: LayersViewModel
  readonly ui: UIViewModel
  readonly history: HistoryViewModel
  readonly viewmodel: IDrawboardCompositeViewModel
}

export const DrawboardContextType = React.createContext<IDrawboardContext>(
  null as unknown as IDrawboardContext,
)
DrawboardContextType.displayName = 'DrawboardContextType'

export const useDrawboardContext = (): IDrawboardContext => {
  return React.useContext(DrawboardContextType)
}

export const useDrawboardGridViewModel = (): GridViewModel => {
  return React.useContext(DrawboardContextType).grid
}

export const useDrawboardLayersViewModel = (): LayersViewModel => {
  return React.useContext(DrawboardContextType).layers
}

export const useDrawboardUIViewModel = (): UIViewModel => {
  return React.useContext(DrawboardContextType).ui
}

export const useDrawboardHistoryViewModel = (): HistoryViewModel => {
  return React.useContext(DrawboardContextType).history
}
