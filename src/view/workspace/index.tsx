import cn from 'clsx'
import React from 'react'
import { PRESET_CLASSES } from '@/constant/classes'
import { WorkspaceContextProvider, useWorkspaceViewmodel } from './context'
import WorkspaceFloat from './float'
import WorkspaceMain from './main'
import WorkspaceSidebar from './sidebar'
import WorkspaceTopbar from './topbar'

export const WorkspaceContaienr: React.FC = () => {
  const viewmodel = useWorkspaceViewmodel()
  return (
    <div className="relative box-border flex min-h-screen w-screen bg-gray-50 font-['Maple_Mono_NF_CN','Roboto_Mono',monospace,sans-serif] text-gray-800 shadow-md transition-colors duration-300 ease-in-out dark:bg-gray-900 dark:text-gray-200 [&::-webkit-scrollbar-thumb]:rounded [&::-webkit-scrollbar-thumb]:bg-gray-300 [&::-webkit-scrollbar-thumb]:hover:bg-gray-400 dark:[&::-webkit-scrollbar-thumb]:bg-gray-600 dark:[&::-webkit-scrollbar-thumb]:hover:bg-gray-500 [&::-webkit-scrollbar-track]:bg-gray-50 dark:[&::-webkit-scrollbar-track]:bg-gray-900 [&::-webkit-scrollbar]:w-2">
      <div className="sticky top-0 box-border h-screen flex-shrink-0 flex-grow-0 border-r border-gray-300 bg-gray-50 shadow-sm dark:border-gray-700 dark:bg-gray-900">
        <WorkspaceSidebar />
      </div>
      <div className="relative box-border flex h-screen w-0 flex-auto flex-col">
        <div className="box-border h-11 w-full flex-initial flex-shrink-0 border-b border-gray-200 bg-gray-50 dark:border-gray-700 dark:bg-gray-900">
          <WorkspaceTopbar />
        </div>
        <div
          ref={el => viewmodel.mainScrollableContainer$.next(el)}
          className={cn(
            'box-border flex-auto h-full w-full overflow-auto',
            PRESET_CLASSES.scrollbar,
          )}
        >
          <WorkspaceMain />
        </div>
      </div>
      <WorkspaceFloat />
    </div>
  )
}

export const WorkspaceView: React.FC = () => {
  return (
    <WorkspaceContextProvider>
      <WorkspaceContaienr />
    </WorkspaceContextProvider>
  )
}

WorkspaceView.displayName = 'WorkspaceView'
export default WorkspaceView
