import React from 'react'
import type { FileViewModel } from './viewmodel'

export interface IFileContext {
  readonly viewmodel: FileViewModel
}

export const FileContextType = React.createContext<IFileContext>({
  viewmodel: null as unknown as FileViewModel,
})
FileContextType.displayName = 'FileContext'

export const useFileViewmodel = (): FileViewModel => React.useContext(FileContextType).viewmodel
