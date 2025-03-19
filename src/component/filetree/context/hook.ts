import React from 'react'
import { FileTreeContextType } from './context'
import type { FileTreeViewModel } from './viewmodel'

export const useFileTreeViewmodel = (): FileTreeViewModel =>
  React.useContext(FileTreeContextType).viewmodel
