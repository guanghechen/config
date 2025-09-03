import type { ISetState } from '@guanghechen/react-viewmodel'
import React from 'react'
import {
  type FileTreeViewModel,
  useFileTreeSearchKeyword,
  useSetFileTreeSearchKeyword,
} from './context'

interface IProps {
  readonly viewmodel: FileTreeViewModel
}

export const FileTreeSearch: React.FC<IProps> = props => {
  const { viewmodel } = props
  const keyword: string = useFileTreeSearchKeyword()
  const setKeyword: ISetState<string> = useSetFileTreeSearchKeyword()

  const onChange = React.useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      const value = e.target.value
      setKeyword(() => value)
      viewmodel.searchKeyword$.next(value)
    },
    [setKeyword, viewmodel.searchKeyword$],
  )

  const onClear = React.useCallback(() => {
    setKeyword(() => '')
    viewmodel.searchKeyword$.next('')
  }, [setKeyword, viewmodel.searchKeyword$])

  return (
    <div className="border-b border-gray-200 px-2 py-2 dark:border-gray-600">
      <div className="relative">
        <input
          type="text"
          value={keyword}
          onChange={onChange}
          placeholder="Search files..."
          className="w-full rounded-md border border-gray-300 px-3 py-1.5 text-sm focus:border-blue-500 focus:outline-hidden focus:ring-1 focus:ring-blue-500 dark:border-gray-600 dark:bg-gray-800 dark:text-gray-100 dark:placeholder-gray-500 dark:focus:border-blue-400 dark:focus:ring-blue-400"
        />
        {keyword && (
          <button
            onClick={onClear}
            className="absolute right-2 top-1/2 -translate-y-1/2 transform text-gray-400 hover:text-gray-600 dark:text-gray-500 dark:hover:text-gray-300"
          >
            ×
          </button>
        )}
      </div>
    </div>
  )
}
