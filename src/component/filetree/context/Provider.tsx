import React from 'react'
import { useSingleton } from '@/hook/useSingleton'
import type { IFileTreeContext } from './context'
import { FileTreeContextType } from './context'
import { FileTreeViewModel } from './viewmodel'

export const FileTreeContextProvider: React.FC<{ children: React.ReactNode }> = props => {
  const viewmodel: FileTreeViewModel | null = useSingleton<FileTreeViewModel>(() => {
    return new FileTreeViewModel({ currentFilepath: null })
  })
  const context: IFileTreeContext | null = React.useMemo<IFileTreeContext | null>(
    () => (viewmodel ? { viewmodel } : null),
    [viewmodel],
  )

  if (!context) return <React.Fragment />

  return (
    <FileTreeContextType.Provider value={context}>{props.children}</FileTreeContextType.Provider>
  )
}
FileTreeContextProvider.displayName = 'FileTreeContextProvider'
