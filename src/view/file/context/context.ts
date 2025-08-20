import React from 'react'
import type { FileViewViewModel } from './viewmodel'

export interface IFileContext {
  readonly viewmodel: FileViewViewModel
}

export const FileViewContextType = React.createContext<IFileContext>({
  viewmodel: null as unknown as FileViewViewModel,
})
FileViewContextType.displayName = 'FileContext'

export const useFileViewmodel = (): FileViewViewModel =>
  React.useContext(FileViewContextType).viewmodel
