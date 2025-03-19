import React from 'react'
import { FileTreeViewModel } from './viewmodel'

export interface IFileTreeContext {
  readonly viewmodel: FileTreeViewModel
}

export const FileTreeContextType = React.createContext<IFileTreeContext>({
  viewmodel: new FileTreeViewModel({}),
})
FileTreeContextType.displayName = 'FileTreeContextType'
