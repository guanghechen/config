import type { ISetState } from '@guanghechen/react-viewmodel'
import { useSetState, useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { FileTreeContextType } from './context'
import type { FileTreeViewModel } from './viewmodel'

export const useFileTreeViewmodel = (): FileTreeViewModel =>
  React.useContext(FileTreeContextType).viewmodel

export const useFileTreeSearchKeyword = (): string => {
  const viewmodel = useFileTreeViewmodel()
  return useStateValue(viewmodel.searchKeyword$)
}

export const useSetFileTreeSearchKeyword = (): ISetState<string> => {
  const viewmodel = useFileTreeViewmodel()
  return useSetState(viewmodel.searchKeyword$)
}
