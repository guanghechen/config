import { useEventCallback } from '@guanghechen/react-hooks'
import React, { useState } from 'react'
import { LANGUAGE_OPTIONS } from './constant'

interface IProps {
  readonly value: string
  readonly onChange: (value: string) => void
}

export const LanguageDropdown: React.FC<IProps> = props => {
  const { value, onChange } = props
  const [isOpen, setIsOpen] = useState(false)
  const currentOption = LANGUAGE_OPTIONS.find(opt => opt.value === value) || LANGUAGE_OPTIONS[0]

  const handleSelect = useEventCallback((optionValue: string): void => {
    onChange(optionValue)
    setIsOpen(false)
  })

  return (
    <div className="relative">
      <button
        onClick={() => setIsOpen(!isOpen)}
        className="flex items-center gap-1.5 px-2 py-1 text-xs rounded border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-700 focus:outline-none focus:ring-1 focus:ring-blue-500"
      >
        <span>{currentOption.label}</span>
        <svg
          className={`w-3 h-3 transition-transform ${isOpen ? 'rotate-180' : ''}`}
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
        </svg>
      </button>
      {isOpen && (
        <React.Fragment>
          <div className="absolute top-full right-0 mt-1 w-36 bg-white dark:bg-gray-800 rounded border border-gray-200 dark:border-gray-600 shadow-lg z-50 max-h-48 overflow-y-auto">
            {LANGUAGE_OPTIONS.map(option => (
              <button
                key={option.value}
                onClick={() => handleSelect(option.value)}
                className={`w-full text-left px-3 py-1.5 text-xs hover:bg-gray-100 dark:hover:bg-gray-700 ${
                  option.value === value
                    ? 'bg-blue-50 dark:bg-blue-900/20 text-blue-700 dark:text-blue-300'
                    : 'text-gray-700 dark:text-gray-300'
                }`}
              >
                {option.label}
              </button>
            ))}
          </div>
          <div className="fixed inset-0 z-40" onClick={() => setIsOpen(false)} />
        </React.Fragment>
      )}
    </div>
  )
}

LanguageDropdown.displayName = 'CodeEditorLanguageDropdown'
