import { useViewModel } from '@guanghechen/react-viewmodel'
import React, { useMemo } from 'react'
import type { DrawboardElement } from '../types/elements'
import type { IDrawboardContext } from './context'
import { DrawboardContextType } from './context'
import type { ToolMode } from './types'
import { DrawboardViewModel } from './viewmodel'

interface IProps {
  mode?: ToolMode
  onSave?: (elements: DrawboardElement[]) => void
  children: React.ReactNode
}

export const DrawboardProvider: React.FC<IProps> = ({ mode, onSave, children }) => {
  const viewmodel = useViewModel<DrawboardViewModel>(() => {
    return new DrawboardViewModel({ mode, onSave })
  })

  const context = useMemo<IDrawboardContext | null>(
    () => (viewmodel ? { viewmodel } : null),
    [viewmodel],
  )

  if (!viewmodel || !context) return null

  return <DrawboardContextType.Provider value={context}>{children}</DrawboardContextType.Provider>
}
