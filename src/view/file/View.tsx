import React from 'react'
import { Composer } from './Composer'
import { FileViewProvider } from './context'

export const FileView: React.FC = () => {
  return (
    <FileViewProvider>
      <Composer />
    </FileViewProvider>
  )
}

FileView.displayName = 'FileView'
