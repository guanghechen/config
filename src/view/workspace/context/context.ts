import React from 'react'
import type { WorkspaceViewViewModel } from './viewmodel'

export interface IWorkspaceContext {
  readonly viewmodel: WorkspaceViewViewModel
}

export const WorkspaceViewContextType = React.createContext<IWorkspaceContext>({
  viewmodel: null as unknown as WorkspaceViewViewModel,
})
WorkspaceViewContextType.displayName = 'WorkspaceContext'

export const useWorkspaceViewmodel = (): WorkspaceViewViewModel =>
  React.useContext(WorkspaceViewContextType).viewmodel
