import { useEventCallback } from '@guanghechen/react-hooks'
import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import type { IFileTreeContext, IFileTreeFileNode } from '@/component/filetree'
import {
  FileTree as FileTreeComponent,
  FileTreeContextType,
  FileTreeViewModel,
} from '@/component/filetree'
import { useWorkspaceFiles } from '@/hook/useWorkspaceFiles'
import { useWorkspaceViewmodel } from '../context'

export const FileTree: React.FC = () => {
  const workspaceVM = useWorkspaceViewmodel()
  const [viewmodel] = React.useState<FileTreeViewModel>(() => {
    const viewmodel = new FileTreeViewModel({})
    return viewmodel
  })

  const context: IFileTreeContext = React.useMemo<IFileTreeContext>(
    () => ({ viewmodel }),
    [viewmodel],
  )

  const onFileNodeClick = useEventCallback((node: IFileTreeFileNode): void => {
    workspaceVM.filepath$.next(node.filepath || node.uuid)
  })

  return (
    <React.Fragment>
      <SideEffect viewmodel={viewmodel} />
      <FileTreeContextType.Provider value={context}>
        <FileTreeComponent viewmodel={viewmodel} onFileNodeClick={onFileNodeClick} />
      </FileTreeContextType.Provider>
    </React.Fragment>
  )
}

const SideEffect: React.FC<{ viewmodel: FileTreeViewModel }> = props => {
  const { viewmodel } = props
  const workspaceVM = useWorkspaceViewmodel()

  const workspace: string | null = useStateValue(workspaceVM.workspace$)
  const { files } = useWorkspaceFiles(workspace, 0)

  React.useEffect(() => {
    viewmodel.updateFromFilepaths(files)
  }, [files])

  return <React.Fragment />
}
SideEffect.displayName = 'FileTreeSideEffect'
