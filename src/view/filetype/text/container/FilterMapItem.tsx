import React, { useEffect, useRef, useState } from 'react'
import type { IFilterMapFunction } from '../context/types'

interface IProps {
  readonly func: IFilterMapFunction
  readonly index: number
  readonly totalCount: number
  readonly onUpdate: (updates: Partial<IFilterMapFunction>) => void
  readonly onRemove: () => void
  readonly onMoveUp: () => void
  readonly onMoveDown: () => void
}

export const FilterMapItem: React.FC<IProps> = ({
  func,
  index,
  totalCount,
  onUpdate,
  onRemove,
  onMoveUp,
  onMoveDown,
}) => {
  const [showDropdown, setShowDropdown] = useState(false)
  const dropdownRef = useRef<HTMLDivElement>(null)

  const handleTypeChange = (newType: 'filter' | 'map'): void => {
    onUpdate({ type: newType })
    setShowDropdown(false)
  }

  useEffect(() => {
    const handleClickOutside = (event: MouseEvent): void => {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
        setShowDropdown(false)
      }
    }

    if (showDropdown) {
      document.addEventListener('mousedown', handleClickOutside)
    }

    return () => {
      document.removeEventListener('mousedown', handleClickOutside)
    }
  }, [showDropdown])
  return (
    <div
      className={`p-3 rounded-lg border transition-opacity ${
        func.skipped === true
          ? 'bg-gray-50 dark:bg-gray-900 border-gray-200 dark:border-gray-800 opacity-50'
          : 'bg-white dark:bg-gray-800 border-gray-200 dark:border-gray-700'
      }`}
    >
      <div className="flex items-center justify-between mb-2">
        <div className="flex items-center space-x-2">
          <div className="flex space-x-1">
            <button
              onClick={onMoveUp}
              disabled={index === 0}
              className="w-6 h-6 flex items-center justify-center text-xs bg-gray-200 dark:bg-gray-700 rounded disabled:opacity-50 disabled:cursor-not-allowed hover:bg-gray-300 dark:hover:bg-gray-600 select-none"
            >
              ↑
            </button>
            <button
              onClick={onMoveDown}
              disabled={index === totalCount - 1}
              className="w-6 h-6 flex items-center justify-center text-xs bg-gray-200 dark:bg-gray-700 rounded disabled:opacity-50 disabled:cursor-not-allowed hover:bg-gray-300 dark:hover:bg-gray-600 select-none"
            >
              ↓
            </button>
          </div>

          <button
            onClick={() => onUpdate({ skipped: !func.skipped })}
            className={`w-6 h-6 flex items-center justify-center transition-colors rounded select-none ${
              func.skipped === true
                ? 'text-blue-500 hover:text-white dark:text-blue-400 dark:hover:text-white bg-blue-50 hover:bg-blue-500 dark:bg-blue-900/20 dark:hover:bg-blue-500 border border-blue-200 dark:border-blue-800 hover:border-blue-500'
                : 'text-gray-400 bg-gray-100 dark:text-gray-500 dark:bg-gray-700 border border-gray-300 dark:border-gray-600 hover:bg-gray-200 dark:hover:bg-gray-600'
            }`}
            title={func.skipped === true ? 'Enable function' : 'Skip function'}
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              className="h-3 w-3"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
              strokeLinecap="round"
              strokeLinejoin="round"
            >
              {func.skipped === true ? (
                <React.Fragment>
                  <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z" />
                  <circle cx="12" cy="12" r="3" />
                </React.Fragment>
              ) : (
                <React.Fragment>
                  <path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24" />
                  <line x1="1" y1="1" x2="23" y2="23" />
                </React.Fragment>
              )}
            </svg>
          </button>

          <button
            onClick={onRemove}
            className="w-6 h-6 flex items-center justify-center text-red-500 hover:text-white dark:text-red-400 dark:hover:text-white bg-red-50 hover:bg-red-500 dark:bg-red-900/20 dark:hover:bg-red-500 border border-red-200 dark:border-red-800 hover:border-red-500 rounded transition-colors select-none"
            title="Remove function"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              className="h-3 w-3"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
              strokeLinecap="round"
              strokeLinejoin="round"
            >
              <path d="M3 6h18M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6m3 0V4c0-1 1-2 2-2h4c0 1 1 2 2 2v2" />
              <line x1="10" y1="11" x2="10" y2="17" />
              <line x1="14" y1="11" x2="14" y2="17" />
            </svg>
          </button>

          <div className="relative" ref={dropdownRef}>
            <div className="flex items-stretch">
              <div
                className={`px-2 py-1 rounded-l text-xs font-medium flex items-center ${
                  func.type === 'filter'
                    ? 'bg-orange-100 text-orange-800 dark:bg-orange-900/50 dark:text-orange-300'
                    : 'bg-purple-100 text-purple-800 dark:bg-purple-900/50 dark:text-purple-300'
                }`}
              >
                {func.type}
              </div>
              <button
                onClick={() => setShowDropdown(!showDropdown)}
                className={`px-1.5 rounded-r border-l border-opacity-20 hover:bg-opacity-80 transition-colors flex items-center justify-center select-none ${
                  func.type === 'filter'
                    ? 'bg-orange-100 text-orange-800 dark:bg-orange-900/50 dark:text-orange-300 border-orange-300 dark:border-orange-600'
                    : 'bg-purple-100 text-purple-800 dark:bg-purple-900/50 dark:text-purple-300 border-purple-300 dark:border-purple-600'
                }`}
                title="Change type"
              >
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  className="h-3 w-3"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="2"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                >
                  <path d="M6 9l6 6 6-6" />
                </svg>
              </button>
            </div>

            {showDropdown && (
              <div className="absolute top-full left-0 mt-1 z-10 bg-white dark:bg-gray-800 border border-gray-300 dark:border-gray-600 rounded shadow-lg">
                <button
                  onClick={() => handleTypeChange('filter')}
                  className={`block w-full px-3 py-2 text-left text-xs hover:bg-gray-100 dark:hover:bg-gray-700 select-none ${
                    func.type === 'filter' ? 'bg-orange-50 dark:bg-orange-900/20' : ''
                  }`}
                >
                  Filter
                </button>
                <button
                  onClick={() => handleTypeChange('map')}
                  className={`block w-full px-3 py-2 text-left text-xs hover:bg-gray-100 dark:hover:bg-gray-700 select-none ${
                    func.type === 'map' ? 'bg-purple-50 dark:bg-purple-900/20' : ''
                  }`}
                >
                  Map
                </button>
              </div>
            )}
          </div>
        </div>
      </div>

      <input
        type="text"
        value={func.function}
        onChange={e => onUpdate({ function: e.target.value })}
        className="w-full rounded-md border border-gray-300 bg-white px-3 py-2 text-sm font-mono dark:border-gray-600 dark:bg-gray-700 dark:text-gray-200"
        placeholder={
          func.type === 'filter'
            ? '(element, index, elements) => condition'
            : '(element, index, elements) => transformed'
        }
      />
    </div>
  )
}

FilterMapItem.displayName = 'FilterMapItem'
