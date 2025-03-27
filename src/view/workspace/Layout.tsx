import React from 'react'
import type { WorkspaceViewModel } from './context'
import WorkspaceFloat from './float'
import WorkspaceMain from './main'
import WorkspaceSidebar from './sidebar'
import WorkspaceTopbar from './topbar'

interface IProps {
  readonly viewmodel: WorkspaceViewModel
}

export class WorkspaceLayout extends React.Component<IProps> {
  public static readonly displayName = 'WorkspaceLayout'

  public override render(): React.ReactElement {
    const { viewmodel } = this.props
    return (
      <div className="relative box-border flex w-screen bg-gray-50 font-['Maple_Mono_NF_CN','Roboto_Mono',monospace,sans-serif] text-gray-800 shadow-md transition-colors duration-300 ease-in-out dark:bg-gray-900 dark:text-gray-200 [&::-webkit-scrollbar-thumb]:rounded [&::-webkit-scrollbar-thumb]:bg-gray-300 [&::-webkit-scrollbar-thumb]:hover:bg-gray-400 dark:[&::-webkit-scrollbar-thumb]:bg-gray-600 dark:[&::-webkit-scrollbar-thumb]:hover:bg-gray-500 [&::-webkit-scrollbar-track]:bg-gray-50 dark:[&::-webkit-scrollbar-track]:bg-gray-900 [&::-webkit-scrollbar]:w-2">
        <div className="sticky top-0 z-30 box-border h-[3rem] w-0 flex-initial">
          <div className="box-border h-full w-screen border-b border-gray-200 bg-gray-50 dark:border-gray-700 dark:bg-gray-900">
            <WorkspaceTopbar viewmodel={viewmodel} />
          </div>
        </div>
        <div className="sticky left-0 top-[3rem] z-30 box-border h-[calc(100vh-3rem)] flex-shrink-0 flex-grow-0 border-r border-gray-300 bg-gray-50 shadow-sm dark:border-gray-700 dark:bg-gray-900">
          <WorkspaceSidebar viewmodel={viewmodel} />
        </div>
        <div className="box-border min-h-screen w-0 flex-auto pt-[3rem]">
          <div className="box-border flex w-full justify-center">
            <WorkspaceMain viewmodel={viewmodel} />
          </div>
        </div>
        <div className="absolute right-0 top-0">
          <WorkspaceFloat viewmodel={viewmodel} />
        </div>
      </div>
    )
  }

  public override shouldComponentUpdate(nextProps: Readonly<IProps>): boolean {
    const props: IProps = this.props
    return props.viewmodel !== nextProps.viewmodel
  }
}
