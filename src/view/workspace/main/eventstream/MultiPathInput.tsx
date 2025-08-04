import cn from 'clsx'
import React from 'react'
import { getPathColorClasses } from './utils'

interface IProps {
  paths: string[]
  onChange: (paths: string[]) => void
  placeholder?: string
}

export const MultiPathInput: React.FC<IProps> = ({ 
  paths, 
  onChange, 
  placeholder = "Add JSON paths (e.g., .data.type)" 
}) => {
  const [inputValue, setInputValue] = React.useState('')
  const [isInputFocused, setIsInputFocused] = React.useState(false)
  const [draggedIndex, setDraggedIndex] = React.useState<number | null>(null)
  const [dragOverIndex, setDragOverIndex] = React.useState<number | null>(null)
  const inputRef = React.useRef<HTMLInputElement>(null)

  const handleInputKeyDown = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Enter' || e.key === ',') {
      e.preventDefault()
      addPath()
    } else if (e.key === 'Backspace' && inputValue === '' && paths.length > 0) {
      // Remove last path when backspacing on empty input
      removePath(paths.length - 1)
    }
  }

  const addPath = () => {
    const trimmedValue = inputValue.trim()
    if (trimmedValue && !paths.includes(trimmedValue)) {
      onChange([...paths, trimmedValue])
    }
    setInputValue('')
  }

  const removePath = (index: number) => {
    const newPaths = paths.filter((_, i) => i !== index)
    onChange(newPaths)
  }

  const handleContainerClick = () => {
    inputRef.current?.focus()
  }

  const handleDragStart = (e: React.DragEvent, index: number) => {
    setDraggedIndex(index)
    e.dataTransfer.effectAllowed = 'move'
    e.dataTransfer.setData('text/plain', '')
  }

  const handleDragOver = (e: React.DragEvent, index: number) => {
    e.preventDefault()
    e.dataTransfer.dropEffect = 'move'
    setDragOverIndex(index)
  }

  const handleDragLeave = () => {
    setDragOverIndex(null)
  }

  const handleDrop = (e: React.DragEvent, dropIndex: number) => {
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

  const handleDragEnd = () => {
    setDraggedIndex(null)
    setDragOverIndex(null)
  }

  return (
    <div
      onClick={handleContainerClick}
      className={cn(
        'flex flex-wrap items-center gap-1 px-3 py-2 min-h-[2.25rem] border rounded-md transition-all cursor-text',
        isInputFocused
          ? 'border-blue-500 ring-2 ring-blue-500/20'
          : 'border-gray-300 dark:border-gray-600',
        'bg-white dark:bg-gray-700 hover:border-gray-400 dark:hover:border-gray-500'
      )}
    >
      {paths.map((path, index) => (
        <span
          key={index}
          draggable
          onDragStart={(e) => handleDragStart(e, index)}
          onDragOver={(e) => handleDragOver(e, index)}
          onDragLeave={handleDragLeave}
          onDrop={(e) => handleDrop(e, index)}
          onDragEnd={handleDragEnd}
          className={cn(
            "inline-flex items-center gap-1 px-2 py-1 text-xs font-medium rounded-md cursor-move transition-all",
            getPathColorClasses(path, paths),
            draggedIndex === index && "opacity-50 scale-95",
            dragOverIndex === index && draggedIndex !== index && "ring-2 ring-blue-400 ring-opacity-50"
          )}
        >
          <svg className="w-3 h-3 opacity-60" fill="currentColor" viewBox="0 0 20 20">
            <path d="M10 6a2 2 0 110-4 2 2 0 010 4zM10 12a2 2 0 110-4 2 2 0 010 4zM10 18a2 2 0 110-4 2 2 0 010 4z"/>
          </svg>
          {path}
          <button
            onClick={(e) => {
              e.stopPropagation()
              removePath(index)
            }}
            className="inline-flex items-center justify-center w-3 h-3 hover:opacity-70 transition-opacity"
            aria-label={`Remove ${path}`}
          >
            <svg className="w-2 h-2" fill="currentColor" viewBox="0 0 8 8">
              <path d="M1.5 1.5l5 5m0-5l-5 5" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
            </svg>
          </button>
        </span>
      ))}
      <input
        ref={inputRef}
        type="text"
        value={inputValue}
        onChange={(e) => setInputValue(e.target.value)}
        onKeyDown={handleInputKeyDown}
        onFocus={() => setIsInputFocused(true)}
        onBlur={() => setIsInputFocused(false)}
        placeholder={paths.length === 0 ? placeholder : ''}
        className="flex-1 min-w-[120px] bg-transparent border-none outline-none text-sm text-gray-900 dark:text-gray-200 placeholder-gray-400 dark:placeholder-gray-500"
      />
    </div>
  )
}