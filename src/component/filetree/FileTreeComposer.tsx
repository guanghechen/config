import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import type { FileTreeViewModel, IFileTreeFileNode } from './context'
import { FileTreeModeEnum } from './context'
import { FileList } from './FileList'
import { FileTree } from './FileTree'

interface IProps {
  readonly viewmodel: FileTreeViewModel
  readonly mode: FileTreeModeEnum
  readonly onFileNodeClick: (node: IFileTreeFileNode) => void
}

export const FileTreeComposer: React.FC<IProps> = props => {
  const { viewmodel, mode, onFileNodeClick } = props
  const searchKeyword: string = useStateValue(viewmodel.searchKeyword$)

  if (mode === FileTreeModeEnum.LIST || searchKeyword.length > 0) {
    return <FileList viewmodel={viewmodel} onFileNodeClick={onFileNodeClick} />
  }
  return <FileTree viewmodel={viewmodel} onFileNodeClick={onFileNodeClick} />
}
