import type { ISetState } from '@guanghechen/react-viewmodel'
import { useSetState, useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { WorkspaceContextType } from './context'
import type { WorkspaceViewModel } from './viewmodel'

export const useWorkspaceViewmodel = (): WorkspaceViewModel =>
  React.useContext(WorkspaceContextType).viewmodel

export const useWorkspace = (): string | null => {
  const viewmodel = useWorkspaceViewmodel()
  return useStateValue(viewmodel.workspace$)
}

export const useCurrentFilepath = (): string | null => {
  const viewmodel = useWorkspaceViewmodel()
  return useStateValue(viewmodel.filepath$)
}

export const useSidebarVisible = (): boolean => {
  const viewmodel = useWorkspaceViewmodel()
  return useStateValue(viewmodel.sidebarVisible$)
}

export const useTopbarVisible = (): boolean => {
  const viewmodel = useWorkspaceViewmodel()
  return useStateValue(viewmodel.topbarVisible$)
}

export const useSidebarWidth = (): number => {
  const viewmodel = useWorkspaceViewmodel()
  return useStateValue(viewmodel.sidebarWidth$)
}

// -------------------------------------------------------------------------------------------------

export const useSetSidebarVisible = (): ISetState<boolean> => {
  const viewmodel = useWorkspaceViewmodel()
  return useSetState(viewmodel.sidebarVisible$)
}

export const useSetTopbarVisible = (): ISetState<boolean> => {
  const viewmodel = useWorkspaceViewmodel()
  return useSetState(viewmodel.topbarVisible$)
}

export const useSetSidebarWidth = (): ISetState<number> => {
  const viewmodel = useWorkspaceViewmodel()
  return useSetState(viewmodel.sidebarWidth$)
}

export const useToggleSidebarVisible = (): (() => void) => {
  const viewmodel = useWorkspaceViewmodel()
  return React.useCallback(() => {
    const visible = viewmodel.sidebarVisible$.getSnapshot()
    viewmodel.sidebarVisible$.next(!visible)
  }, [viewmodel.sidebarVisible$])
}

export const useToggleTopbarVisible = (): (() => void) => {
  const viewmodel = useWorkspaceViewmodel()
  return React.useCallback(() => {
    const visible = viewmodel.topbarVisible$.getSnapshot()
    viewmodel.topbarVisible$.next(!visible)
  }, [viewmodel.topbarVisible$])
}

export const useToggleBothSidebarAndTopbar = (): (() => void) => {
  const viewmodel = useWorkspaceViewmodel()
  return React.useCallback(() => {
    const sidebarVisible = viewmodel.sidebarVisible$.getSnapshot()
    const topbarVisible = viewmodel.topbarVisible$.getSnapshot()
    const newVisibility = !(sidebarVisible && topbarVisible)
    viewmodel.sidebarVisible$.next(newVisibility)
    viewmodel.topbarVisible$.next(newVisibility)
  }, [viewmodel.sidebarVisible$, viewmodel.topbarVisible$])
}
