import { useStateValue } from '@guanghechen/react-viewmodel'
import type { Root } from '@yozora/ast'
import React from 'react'
import { ReactMarkdown } from '@/component/markdown'
import type { SiteTheme } from '@/context/site'
import { useSiteViewmodel } from '@/context/site'
import { useFileResult } from '@/hook/useFileResult'
import { TopbarView } from '../topbar'

export const MarkdownView: React.FC = () => {
  const siteViewModel = useSiteViewmodel()
  const theme: SiteTheme = useStateValue(siteViewModel.theme$)
  const workspace: string | null = useStateValue(siteViewModel.workspace$)
  const filepath = useStateValue(siteViewModel.filepath$)
  const tick: number = useStateValue(siteViewModel.filepathDirtyTick$)
  const { data, error } = useFileResult(workspace, filepath, tick)
  const ast: Root | undefined = data?.ast

  return (
    <div className="box-border flex h-screen w-screen flex-col bg-[#fdfdfd] font-['Maple_Mono_NF_CN','Roboto_Mono',monospace,sans-serif] text-gray-800 shadow-md transition-colors duration-300 ease-in-out dark:bg-[#1a1a1a] dark:text-gray-200 [&::-webkit-scrollbar-thumb]:rounded [&::-webkit-scrollbar-thumb]:bg-gray-300 [&::-webkit-scrollbar-thumb]:hover:bg-gray-400 dark:[&::-webkit-scrollbar-thumb]:bg-gray-600 dark:[&::-webkit-scrollbar-thumb]:hover:bg-gray-500 [&::-webkit-scrollbar-track]:bg-gray-100 dark:[&::-webkit-scrollbar-track]:bg-gray-800 [&::-webkit-scrollbar]:w-2">
      <TopbarView />
      <div className="flex flex-1 flex-col overflow-auto [&::-webkit-scrollbar-thumb]:rounded [&::-webkit-scrollbar-thumb]:bg-gray-300 [&::-webkit-scrollbar-thumb]:hover:bg-gray-400 dark:[&::-webkit-scrollbar-thumb]:bg-gray-600 dark:[&::-webkit-scrollbar-thumb]:hover:bg-gray-500 [&::-webkit-scrollbar-track]:bg-gray-100 dark:[&::-webkit-scrollbar-track]:bg-gray-800 [&::-webkit-scrollbar]:w-2">
        {!!error && (
          <div className="flex-none bg-gray-100 px-2 py-1.5 text-base text-red-500 dark:bg-gray-800 dark:text-red-400">
            <code>error: {String(error)}</code>
          </div>
        )}
        {!!ast && (
          <div className="my-5 flex flex-1 justify-center">
            <div className="w-[800px]">
              <ReactMarkdown ast={ast} theme={theme} />
            </div>
          </div>
        )}
      </div>
    </div>
  )
}
