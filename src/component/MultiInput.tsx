/* eslint-disable no-param-reassign */
import cn from 'clsx'
import React from 'react'

export type DisplayMode = 'inline' | 'lines'

export interface IMultiInputItem {
  value: string
  visible: boolean
}

interface IProps<T extends IMultiInputItem> {
  items: T[]
  onChange: (items: T[]) => void
  placeholder?: string
  displayMode: DisplayMode
  onDisplayModeChange: (mode: DisplayMode) => void
  createItem: (value: string) => T
  getItemColorClasses?: (item: T, allItems: T[]) => string
  renderItemContent?: (item: T) => React.ReactNode
  allowDuplicates?: boolean
}

export const MultiInput = <T extends IMultiInputItem>({
  items,
  onChange,
  placeholder = 'Add items',
  displayMode,
  onDisplayModeChange,
  createItem,
  getItemColorClasses,
  renderItemContent,
  allowDuplicates = false,
}: IProps<T>): React.ReactElement => {
  const [inputValue, setInputValue] = React.useState('')
  const [isInputFocused, setIsInputFocused] = React.useState(false)
  const [draggedIndex, setDraggedIndex] = React.useState<number | null>(null)
  const [dragOverIndex, setDragOverIndex] = React.useState<number | null>(null)
  const inputRef = React.useRef<HTMLInputElement>(null)

  const itemValues = React.useMemo(() => items.map(item => item.value), [items])

  const handleInputKeyDown = (e: React.KeyboardEvent<HTMLInputElement>): void => {
    if (e.key === 'Enter' || e.key === ',') {
      e.preventDefault()
      addItem()
    } else if (e.key === 'Backspace' && inputValue === '' && items.length > 0) {
      removeItem(items.length - 1)
    }
  }

  const addItem = (): void => {
    const trimmedValue = inputValue.trim()
    if (trimmedValue && (allowDuplicates || !itemValues.includes(trimmedValue))) {
      onChange([...items, createItem(trimmedValue)])
    }
    setInputValue('')
  }

  const removeItem = (index: number): void => {
    const newItems = items.filter((_, i) => i !== index)
    onChange(newItems)
  }

  const toggleVisibility = (index: number): void => {
    const newItems = items.map((item, i) => {
      if (i === index) {
        const updatedItem: T = { ...item, visible: !item.visible }
        return updatedItem
      }
      return item
    })
    onChange(newItems)
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

    const newItems = [...items]
    const [draggedItem] = newItems.splice(draggedIndex, 1)
    newItems.splice(dropIndex, 0, draggedItem)

    onChange(newItems)
    setDraggedIndex(null)
    setDragOverIndex(null)
  }

  const handleDragEnd = (): void => {
    setDraggedIndex(null)
    setDragOverIndex(null)
  }

  const getDefaultColorClasses = (): string => {
    return 'bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-300'
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
          items.map((item, index) => (
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
                getItemColorClasses ? getItemColorClasses(item, items) : getDefaultColorClasses(),
                !item.visible && 'opacity-50',
                draggedIndex === index && 'opacity-50 scale-95',
                dragOverIndex === index &&
                  draggedIndex !== index &&
                  'ring-2 ring-blue-400 ring-opacity-50',
              )}
            >
              <svg className="w-3 h-3 opacity-60" fill="currentColor" viewBox="0 0 20 20">
                <path d="M10 6a2 2 0 110-4 2 2 0 010 4zM10 12a2 2 0 110-4 2 2 0 010 4zM10 18a2 2 0 110-4 2 2 0 010 4z" />
              </svg>
              {renderItemContent ? renderItemContent(item) : item.value}
              <button
                onClick={e => {
                  e.stopPropagation()
                  toggleVisibility(index)
                }}
                className="inline-flex items-center justify-center w-3 h-3 hover:opacity-70 transition-opacity"
                aria-label={item.visible ? `Hide ${item.value}` : `Show ${item.value}`}
              >
                {item.visible ? (
                  <svg className="w-3 h-3" fill="currentColor" viewBox="0 0 20 20">
                    <path d="M10 12a2 2 0 100-4 2 2 0 000 4z" />
                    <path
                      fillRule="evenodd"
                      d="M.458 10C1.732 5.943 5.522 3 10 3s8.268 2.943 9.542 7c-1.274 4.057-5.064 7-9.542 7S1.732 14.057.458 10zM14 10a4 4 0 11-8 0 4 4 0 018 0z"
                      clipRule="evenodd"
                    />
                  </svg>
                ) : (
                  <svg className="w-3 h-3" fill="currentColor" viewBox="0 0 20 20">
                    <path
                      fillRule="evenodd"
                      d="M3.707 2.293a1 1 0 00-1.414 1.414l14 14a1 1 0 001.414-1.414l-1.473-1.473A10.014 10.014 0 0019.542 10C18.268 5.943 14.478 3 10 3a9.958 9.958 0 00-4.512 1.074l-1.78-1.781zm4.261 4.26l1.514 1.515a2.003 2.003 0 012.45 2.45l1.514 1.514a4 4 0 00-5.478-5.478z"
                      clipRule="evenodd"
                    />
                    <path d="M12.454 16.697L9.75 13.992a4 4 0 01-3.742-3.741L2.335 6.578A9.98 9.98 0 00.458 10c1.274 4.057 5.065 7 9.542 7 .847 0 1.669-.105 2.454-.303z" />
                  </svg>
                )}
              </button>
              <button
                onClick={e => {
                  e.stopPropagation()
                  removeItem(index)
                }}
                className="inline-flex items-center justify-center w-3 h-3 hover:opacity-70 transition-opacity"
                aria-label={`Remove ${item.value}`}
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
          placeholder={displayMode === 'inline' && items.length > 0 ? '' : placeholder}
          className="flex-1 min-w-[120px] bg-transparent border-none outline-none text-sm text-gray-900 dark:text-gray-200 placeholder-gray-400 dark:placeholder-gray-500"
        />
        <button
          onClick={e => {
            e.stopPropagation()
            onDisplayModeChange(displayMode === 'inline' ? 'lines' : 'inline')
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
      {displayMode === 'lines' && items.length > 0 && (
        <div className="space-y-1">
          {items.map((item, index) => (
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
                getItemColorClasses ? getItemColorClasses(item, items) : getDefaultColorClasses(),
                'border-current border-opacity-20',
                !item.visible && 'opacity-50',
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
              <span className="flex-1 text-sm font-medium">
                {renderItemContent ? renderItemContent(item) : item.value}
              </span>
              <button
                onClick={e => {
                  e.stopPropagation()
                  toggleVisibility(index)
                }}
                className="flex-shrink-0 inline-flex items-center justify-center w-5 h-5 rounded hover:bg-black hover:bg-opacity-10 dark:hover:bg-white dark:hover:bg-opacity-10 transition-colors"
                aria-label={item.visible ? `Hide ${item.value}` : `Show ${item.value}`}
              >
                {item.visible ? (
                  <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                    <path d="M10 12a2 2 0 100-4 2 2 0 000 4z" />
                    <path
                      fillRule="evenodd"
                      d="M.458 10C1.732 5.943 5.522 3 10 3s8.268 2.943 9.542 7c-1.274 4.057-5.064 7-9.542 7S1.732 14.057.458 10zM14 10a4 4 0 11-8 0 4 4 0 018 0z"
                      clipRule="evenodd"
                    />
                  </svg>
                ) : (
                  <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                    <path
                      fillRule="evenodd"
                      d="M3.707 2.293a1 1 0 00-1.414 1.414l14 14a1 1 0 001.414-1.414l-1.473-1.473A10.014 10.014 0 0019.542 10C18.268 5.943 14.478 3 10 3a9.958 9.958 0 00-4.512 1.074l-1.78-1.781zm4.261 4.26l1.514 1.515a2.003 2.003 0 012.45 2.45l1.514 1.514a4 4 0 00-5.478-5.478z"
                      clipRule="evenodd"
                    />
                    <path d="M12.454 16.697L9.75 13.992a4 4 0 01-3.742-3.741L2.335 6.578A9.98 9.98 0 00.458 10c1.274 4.057 5.065 7 9.542 7 .847 0 1.669-.105 2.454-.303z" />
                  </svg>
                )}
              </button>
              <button
                onClick={e => {
                  e.stopPropagation()
                  removeItem(index)
                }}
                className="flex-shrink-0 inline-flex items-center justify-center w-5 h-5 rounded hover:bg-black hover:bg-opacity-10 dark:hover:bg-white dark:hover:bg-opacity-10 transition-colors"
                aria-label={`Remove ${item.value}`}
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
