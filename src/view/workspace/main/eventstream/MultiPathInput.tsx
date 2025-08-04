/* eslint-disable no-param-reassign */
import cn from 'clsx'
import React from 'react'
import { getPathColorClasses } from './utils'

interface IProps {
  paths: string[]
  onChange: (paths: string[]) => void
  placeholder?: string
}

type DisplayMode = 'inline' | 'lines'

export const MultiPathInput: React.FC<IProps> = ({
  paths,
  onChange,
  placeholder = 'Add JSON paths (e.g., .data.type)',
}) => {
  const [inputValue, setInputValue] = React.useState('')
  const [isInputFocused, setIsInputFocused] = React.useState(false)
  const [draggedIndex, setDraggedIndex] = React.useState<number | null>(null)
  const [dragOverIndex, setDragOverIndex] = React.useState<number | null>(null)
  const [displayMode, setDisplayMode] = React.useState<DisplayMode>('lines')
  const inputRef = React.useRef<HTMLInputElement>(null)

  const handleInputKeyDown = (e: React.KeyboardEvent<HTMLInputElement>): void => {
    if (e.key === 'Enter' || e.key === ',') {
      e.preventDefault()
      addPath()
    } else if (e.key === 'Backspace' && inputValue === '' && paths.length > 0) {
      removePath(paths.length - 1)
    }
  }

  const addPath = (): void => {
    const trimmedValue = inputValue.trim()
    if (trimmedValue && !paths.includes(trimmedValue)) {
      onChange([...paths, trimmedValue])
    }
    setInputValue('')
  }

  const removePath = (index: number): void => {
    const newPaths = paths.filter((_, i) => i !== index)
    onChange(newPaths)
  }

  const handleContainerClick = (): void => {
    inputRef.current?.focus()
  }

  const handleDragStart = (e: React.DragEvent, index: number): void => {
    setDraggedIndex(index)
    e.dataTransfer.effectAllowed = 'move'
    e.dataTransfer.setData('text/plain', '')
  }

  const handleDragOver = (e: React.DragEvent, index: number): void => {
    e.preventDefault()
    e.dataTransfer.dropEffect = 'move'
    setDragOverIndex(index)
  }

  const handleDragLeave = (): void => {
    setDragOverIndex(null)
  }

  const handleDrop = (e: React.DragEvent, dropIndex: number): void => {
    e.preventDefault()

    if (draggedIndex === null || draggedIndex === dropIndex) {
      setDraggedIndex(null)
      setDragOverIndex(null)
      return
    }

    const newPaths = [...paths]
    const [draggedPath] = newPaths.splice(draggedIndex, 1)
    newPaths.splice(dropIndex, 0, draggedPath)

    onChange(newPaths)
    setDraggedIndex(null)
    setDragOverIndex(null)
  }

  const handleDragEnd = (): void => {
    setDraggedIndex(null)
    setDragOverIndex(null)
  }

  return (
    <div className="space-y-2">
      <div
        onClick={handleContainerClick}
        className={cn(
          'flex items-center gap-1 px-3 py-2 min-h-[2.25rem] border rounded-md transition-all cursor-text',
          isInputFocused
            ? 'border-blue-500 ring-2 ring-blue-500/20'
            : 'border-gray-300 dark:border-gray-600',
          'bg-white dark:bg-gray-700 hover:border-gray-400 dark:hover:border-gray-500',
        )}
      >
        {displayMode === 'inline' &&
          paths.map((path, index) => (
            <span
              key={index}
              draggable={true}
              onDragStart={e => handleDragStart(e, index)}
              onDragOver={e => handleDragOver(e, index)}
              onDragLeave={handleDragLeave}
              onDrop={e => handleDrop(e, index)}
              onDragEnd={handleDragEnd}
              className={cn(
                'inline-flex items-center gap-1 px-2 py-1 text-xs font-medium rounded-md cursor-move transition-all',
                getPathColorClasses(path, paths),
                draggedIndex === index && 'opacity-50 scale-95',
                dragOverIndex === index &&
                  draggedIndex !== index &&
                  'ring-2 ring-blue-400 ring-opacity-50',
              )}
            >
              <svg className="w-3 h-3 opacity-60" fill="currentColor" viewBox="0 0 20 20">
                <path d="M10 6a2 2 0 110-4 2 2 0 010 4zM10 12a2 2 0 110-4 2 2 0 010 4zM10 18a2 2 0 110-4 2 2 0 010 4z" />
              </svg>
              {path}
              <button
                onClick={e => {
                  e.stopPropagation()
                  removePath(index)
                }}
                className="inline-flex items-center justify-center w-3 h-3 hover:opacity-70 transition-opacity"
                aria-label={`Remove ${path}`}
              >
                <svg className="w-2 h-2" fill="currentColor" viewBox="0 0 8 8">
                  <path
                    d="M1.5 1.5l5 5m0-5l-5 5"
                    stroke="currentColor"
                    strokeWidth="1.5"
                    strokeLinecap="round"
                  />
                </svg>
              </button>
            </span>
          ))}

        <input
          ref={inputRef}
          type="text"
          value={inputValue}
          onChange={e => setInputValue(e.target.value)}
          onKeyDown={handleInputKeyDown}
          onFocus={() => setIsInputFocused(true)}
          onBlur={() => setIsInputFocused(false)}
          placeholder={displayMode === 'inline' && paths.length > 0 ? '' : placeholder}
          className="flex-1 min-w-[120px] bg-transparent border-none outline-none text-sm text-gray-900 dark:text-gray-200 placeholder-gray-400 dark:placeholder-gray-500"
        />
        <button
          onClick={e => {
            e.stopPropagation()
            setDisplayMode(displayMode === 'inline' ? 'lines' : 'inline')
          }}
          className="flex-shrink-0 inline-flex items-center justify-center w-8 h-8 rounded hover:bg-gray-100 dark:hover:bg-gray-600 transition-colors"
          title={displayMode === 'inline' ? 'Switch to lines mode' : 'Switch to inline mode'}
          aria-label={displayMode === 'inline' ? 'Switch to lines mode' : 'Switch to inline mode'}
        >
          {displayMode === 'inline' ? (
            <svg
              className="w-4 h-4 text-gray-500 dark:text-gray-400"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M4 6h16M4 12h16M4 18h16"
              />
            </svg>
          ) : (
            <svg
              className="w-4 h-4 text-gray-500 dark:text-gray-400"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a1.994 1.994 0 01-1.414.586H7a4 4 0 01-4-4V7a4 4 0 014-4z"
              />
            </svg>
          )}
        </button>
      </div>
      {displayMode === 'lines' && paths.length > 0 && (
        <div className="space-y-1">
          {paths.map((path, index) => (
            <div
              key={index}
              draggable={true}
              onDragStart={e => handleDragStart(e, index)}
              onDragOver={e => handleDragOver(e, index)}
              onDragLeave={handleDragLeave}
              onDrop={e => handleDrop(e, index)}
              onDragEnd={handleDragEnd}
              className={cn(
                'flex items-center gap-2 px-3 py-2 rounded-md cursor-move transition-all border',
                getPathColorClasses(path, paths),
                'border-current border-opacity-20',
                draggedIndex === index && 'opacity-50 scale-98',
                dragOverIndex === index &&
                  draggedIndex !== index &&
                  'ring-2 ring-blue-400 ring-opacity-50 scale-102',
              )}
            >
              <svg
                className="w-4 h-4 opacity-60 flex-shrink-0"
                fill="currentColor"
                viewBox="0 0 20 20"
              >
                <path d="M10 6a2 2 0 110-4 2 2 0 010 4zM10 12a2 2 0 110-4 2 2 0 010 4zM10 18a2 2 0 110-4 2 2 0 010 4z" />
              </svg>
              <span className="flex-1 text-sm font-medium">{path}</span>
              <button
                onClick={e => {
                  e.stopPropagation()
                  removePath(index)
                }}
                className="flex-shrink-0 inline-flex items-center justify-center w-5 h-5 rounded hover:bg-black hover:bg-opacity-10 dark:hover:bg-white dark:hover:bg-opacity-10 transition-colors"
                aria-label={`Remove ${path}`}
              >
                <svg className="w-3 h-3" fill="currentColor" viewBox="0 0 8 8">
                  <path
                    d="M1.5 1.5l5 5m0-5l-5 5"
                    stroke="currentColor"
                    strokeWidth="1.5"
                    strokeLinecap="round"
                  />
                </svg>
              </button>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
