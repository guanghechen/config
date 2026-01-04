import React from 'react'
import type { FileTreeViewModel } from './viewmodel'

export interface IFileTreeContext {
  readonly viewmodel: FileTreeViewModel
}

export const FileTreeContextType = React.createContext<IFileTreeContext>({
  viewmodel: null as unknown as FileTreeViewModel,
})
FileTreeContextType.displayName = 'FileTreeContextType'
