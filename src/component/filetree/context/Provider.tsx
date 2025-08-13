import React from 'react'
import { useSingleton } from '@/hook/useSingleton'
import type { IFileTreeContext } from './context'
import { FileTreeContextType } from './context'
import { FileTreeViewModel } from './viewmodel'

export const FileTreeContextProvider: React.FC<{ children: React.ReactNode }> = props => {
  const viewmodel: FileTreeViewModel = useSingleton<FileTreeViewModel>(() => {
    return new FileTreeViewModel({ currentFilepath: null })
  })

  const context: IFileTreeContext = React.useMemo<IFileTreeContext>(
    () => ({ viewmodel }),
    [viewmodel],
  )

  return (
    <FileTreeContextType.Provider value={context}>{props.children}</FileTreeContextType.Provider>
  )
}
FileTreeContextProvider.displayName = 'FileTreeContextProvider'
