import { Subscriber, useViewModel } from '@guanghechen/react-viewmodel'
import React, { useEffect, useMemo } from 'react'
import type { IDrawboardElement } from '../types/elements'
import type { IDrawboardCompositeViewModel, IDrawboardContext } from './context'
import { DrawboardContextType } from './context'
import type { ToolMode } from './types'
import { GridViewModel } from './viewmodel/grid'
import { HistoryViewModel } from './viewmodel/history'
import type { ILayerManagerData } from './viewmodel/layers'
import { LayersViewModel } from './viewmodel/layers'
import { UIViewModel } from './viewmodel/ui'

interface IProps {
  mode?: ToolMode
  initialElements?: IDrawboardElement[]
  onSave?: (elements: IDrawboardElement[]) => void
  children: React.ReactNode
}

export const DrawboardProvider: React.FC<IProps> = ({ mode, initialElements = [], children }) => {
  const gridViewModel = useViewModel<GridViewModel>(() => {
    return new GridViewModel()
  })

  const layersViewModel = useViewModel<LayersViewModel>(() => {
    const layers = new LayersViewModel()
    // Set initial elements if provided
    if (initialElements.length > 0) {
      layers.setActiveLayerElements(initialElements)
    }
    return layers
  })

  const uiViewModel = useViewModel<UIViewModel>(() => {
    return new UIViewModel({ mode })
  })

  const historyViewModel = useViewModel<HistoryViewModel>(() => {
    return new HistoryViewModel()
  })

  // Initialize history with initial layer data
  useEffect(() => {
    if (layersViewModel && historyViewModel) {
      const initialLayerData = layersViewModel.dump()
      historyViewModel.initializeWith(initialLayerData)
    }
  }, [layersViewModel, historyViewModel])

  // Sync history with layer changes
  useEffect(() => {
    if (!layersViewModel || !historyViewModel) return

    const subscription = layersViewModel.layers$.subscribe(
      new Subscriber({
        onNext: () => {
          const layerData = layersViewModel.dump()
          historyViewModel.updateLayerData(layerData)
        },
      }),
    )

    return () => subscription.unsubscribe()
  }, [layersViewModel, historyViewModel])

  // Sync layer changes from history
  useEffect(() => {
    if (!layersViewModel || !historyViewModel) return

    const subscription = historyViewModel.layerData$.subscribe(
      new Subscriber<ILayerManagerData | null>({
        onNext: (layerData: ILayerManagerData | null) => {
          if (layerData) {
            layersViewModel.load(layerData)
          }
        },
      }),
    )

    return () => subscription.unsubscribe()
  }, [layersViewModel, historyViewModel])

  const compositeViewModel = useMemo<IDrawboardCompositeViewModel | null>(() => {
    if (!gridViewModel || !layersViewModel || !uiViewModel || !historyViewModel) return null

    return {
      undo: () => {
        historyViewModel.undo()
      },

      redo: () => {
        historyViewModel.redo()
      },

      canUndo: () => {
        return historyViewModel.canUndo()
      },

      canRedo: () => {
        return historyViewModel.canRedo()
      },

      saveToHistory: () => {
        historyViewModel.saveToHistory()
      },
    }
  }, [gridViewModel, layersViewModel, uiViewModel, historyViewModel])

  const context = useMemo<IDrawboardContext | null>(() => {
    if (
      !gridViewModel ||
      !layersViewModel ||
      !uiViewModel ||
      !historyViewModel ||
      !compositeViewModel
    )
      return null

    return {
      grid: gridViewModel,
      layers: layersViewModel,
      ui: uiViewModel,
      history: historyViewModel,
      viewmodel: compositeViewModel,
    }
  }, [gridViewModel, layersViewModel, uiViewModel, historyViewModel, compositeViewModel])

  if (!context) return null

  return <DrawboardContextType.Provider value={context}>{children}</DrawboardContextType.Provider>
}
