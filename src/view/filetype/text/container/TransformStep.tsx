import cn from 'clsx'
import React from 'react'
import { CodeBox } from '@/component/CodeBox'
import type { ITextTransformStep } from '@/shared/types'
import { TextTransformStepTypeEnum } from '@/shared/types'

interface IProps {
  readonly step: ITextTransformStep
  readonly index: number
  readonly totalCount: number
  readonly onUpdate: (updates: Partial<ITextTransformStep>) => void
  readonly onRemove: () => void
  readonly onMoveUp: () => void
  readonly onMoveDown: () => void
  readonly onDuplicate: () => void
  readonly onDragStart?: (index: number) => void
  readonly onDragOver?: (index: number) => void
  readonly onDrop?: (fromIndex: number, toIndex: number) => void
}

export const TransformStep: React.FC<IProps> = props => {
  const {
    step,
    index,
    totalCount,
    onUpdate,
    onRemove,
    onMoveUp,
    onMoveDown,
    onDuplicate,
    onDragStart,
    onDragOver,
    onDrop,
  } = props
  const [showDropdown, setShowDropdown] = React.useState<boolean>(false)
  const [isDragging, setIsDragging] = React.useState<boolean>(false)
  const [isDropTarget, setIsDropTarget] = React.useState<boolean>(false)
  const dropdownRef = React.useRef<HTMLDivElement | null>(null)
  const itemRef = React.useRef<HTMLDivElement | null>(null)

  const handleTypeChange = (newType: TextTransformStepTypeEnum): void => {
    onUpdate({ type: newType })
    setShowDropdown(false)
  }

  const handleDragStart = (e: React.DragEvent): void => {
    setIsDragging(true)
    const dataTransfer = e.dataTransfer
    dataTransfer.effectAllowed = 'move'
    dataTransfer.setData('text/plain', index.toString())

    // Create custom drag preview
    if (itemRef.current) {
      const rect = itemRef.current.getBoundingClientRect()
      const dragPreview = itemRef.current.cloneNode(true) as HTMLElement
      dragPreview.style.position = 'absolute'
      dragPreview.style.top = '-1000px'
      dragPreview.style.left = '-1000px'
      dragPreview.style.width = `${rect.width}px`
      dragPreview.style.transform = 'rotate(5deg)'
      dragPreview.style.opacity = '0.8'
      dragPreview.style.pointerEvents = 'none'
      dragPreview.style.zIndex = '1000'
      dragPreview.style.backgroundColor = 'white'
      dragPreview.style.border = '2px solid #3b82f6'
      dragPreview.style.borderRadius = '8px'
      dragPreview.style.boxShadow = '0 10px 25px rgba(0, 0, 0, 0.3)'

      document.body.appendChild(dragPreview)
      dataTransfer.setDragImage(dragPreview, rect.width / 2, rect.height / 2)

      // Clean up the preview element after drag starts
      setTimeout(() => {
        if (document.body.contains(dragPreview)) {
          document.body.removeChild(dragPreview)
        }
      }, 0)
    }

    onDragStart?.(index)
  }

  const handleDragEnd = (): void => {
    setIsDragging(false)
    setIsDropTarget(false)
  }

  const handleDragEnter = (e: React.DragEvent): void => {
    e.preventDefault()
    setIsDropTarget(true)
  }

  const handleDragLeave = (e: React.DragEvent): void => {
    e.preventDefault()
    // Only set to false if we're leaving the item entirely
    if (!e.currentTarget.contains(e.relatedTarget as Node)) {
      setIsDropTarget(false)
    }
  }

  const handleDragOver = (e: React.DragEvent): void => {
    e.preventDefault()
    const dataTransfer = e.dataTransfer
    dataTransfer.dropEffect = 'move'
    setIsDropTarget(true)
    onDragOver?.(index)
  }

  const handleDrop = (e: React.DragEvent): void => {
    e.preventDefault()
    const draggedIdx = parseInt(e.dataTransfer.getData('text/plain'), 10)
    if (draggedIdx !== index) {
      onDrop?.(draggedIdx, index)
    }
    setIsDragging(false)
    setIsDropTarget(false)
  }

  React.useEffect(() => {
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
      ref={itemRef}
      className={cn('p-3 rounded-lg border transition-all duration-200', {
        'bg-gray-50 dark:bg-gray-900 border-gray-200 dark:border-gray-800 opacity-50':
          step.skip === true,
        'bg-white dark:bg-gray-800 border-gray-200 dark:border-gray-700': step.skip !== true,
        'opacity-50 scale-95': isDragging,
        'ring-2 ring-blue-500 border-blue-500 bg-blue-50 dark:bg-blue-900/20 transform scale-105':
          isDropTarget && !isDragging,
      })}
      onDragOver={handleDragOver}
      onDragEnter={handleDragEnter}
      onDragLeave={handleDragLeave}
      onDrop={handleDrop}
    >
      <div className="flex items-center justify-between mb-2">
        <div className="flex items-center space-x-2">
          <div className="flex space-x-1">
            <button
              draggable={true}
              onDragStart={handleDragStart}
              onDragEnd={handleDragEnd}
              className="w-6 h-6 flex items-center justify-center text-xs bg-gray-200 dark:bg-gray-700 rounded hover:bg-gray-300 dark:hover:bg-gray-600 select-none cursor-grab active:cursor-grabbing"
              title="Drag to reorder"
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
                <circle cx="9" cy="12" r="1" />
                <circle cx="9" cy="5" r="1" />
                <circle cx="9" cy="19" r="1" />
                <circle cx="15" cy="12" r="1" />
                <circle cx="15" cy="5" r="1" />
                <circle cx="15" cy="19" r="1" />
              </svg>
            </button>
            <button
              onClick={onMoveUp}
              disabled={index === 0}
              className="w-6 h-6 flex items-center justify-center text-xs bg-gray-200 dark:bg-gray-700 rounded disabled:opacity-50 disabled:cursor-not-allowed hover:bg-gray-300 dark:hover:bg-gray-600 select-none cursor-pointer"
            >
              ↑
            </button>
            <button
              onClick={onMoveDown}
              disabled={index === totalCount - 1}
              className="w-6 h-6 flex items-center justify-center text-xs bg-gray-200 dark:bg-gray-700 rounded disabled:opacity-50 disabled:cursor-not-allowed hover:bg-gray-300 dark:hover:bg-gray-600 select-none cursor-pointer"
            >
              ↓
            </button>
            <button
              onClick={onDuplicate}
              className="w-6 h-6 flex items-center justify-center text-blue-500 hover:text-white dark:text-blue-400 dark:hover:text-white bg-blue-50 hover:bg-blue-500 dark:bg-blue-900/20 dark:hover:bg-blue-500 border border-blue-200 dark:border-blue-800 hover:border-blue-500 rounded transition-colors select-none cursor-pointer"
              title="Duplicate function"
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
                <rect x="9" y="9" width="13" height="13" rx="2" ry="2" />
                <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1" />
              </svg>
            </button>
          </div>

          <button
            onClick={() => onUpdate({ skip: !step.skip })}
            className={cn(
              'w-6 h-6 flex items-center justify-center transition-colors rounded select-none cursor-pointer',
              {
                'text-blue-500 hover:text-white dark:text-blue-400 dark:hover:text-white bg-blue-50 hover:bg-blue-500 dark:bg-blue-900/20 dark:hover:bg-blue-500 border border-blue-200 dark:border-blue-800 hover:border-blue-500':
                  step.skip === true,
                'text-gray-400 bg-gray-100 dark:text-gray-500 dark:bg-gray-700 border border-gray-300 dark:border-gray-600 hover:bg-gray-200 dark:hover:bg-gray-600':
                  step.skip !== true,
              },
            )}
            title={step.skip === true ? 'Enable function' : 'Skip function'}
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
              {step.skip === true ? (
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
            className="w-6 h-6 flex items-center justify-center text-red-500 hover:text-white dark:text-red-400 dark:hover:text-white bg-red-50 hover:bg-red-500 dark:bg-red-900/20 dark:hover:bg-red-500 border border-red-200 dark:border-red-800 hover:border-red-500 rounded transition-colors select-none cursor-pointer"
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
                className={cn('px-2 py-1 rounded-l text-xs font-medium flex items-center', {
                  'bg-orange-100 text-orange-800 dark:bg-orange-900/50 dark:text-orange-300':
                    step.type === TextTransformStepTypeEnum.FILTER,
                  'bg-purple-100 text-purple-800 dark:bg-purple-900/50 dark:text-purple-300':
                    step.type !== TextTransformStepTypeEnum.FILTER,
                })}
              >
                {step.type}
              </div>
              <button
                onClick={() => setShowDropdown(!showDropdown)}
                className={cn(
                  'px-1.5 rounded-r border-l border-opacity-20 hover:bg-opacity-80 transition-colors flex items-center justify-center select-none cursor-pointer',
                  {
                    'bg-orange-100 text-orange-800 dark:bg-orange-900/50 dark:text-orange-300 border-orange-300 dark:border-orange-600':
                      step.type === TextTransformStepTypeEnum.FILTER,
                    'bg-purple-100 text-purple-800 dark:bg-purple-900/50 dark:text-purple-300 border-purple-300 dark:border-purple-600':
                      step.type !== TextTransformStepTypeEnum.FILTER,
                  },
                )}
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
                  onClick={() => handleTypeChange(TextTransformStepTypeEnum.FILTER)}
                  className={cn(
                    'block w-full px-3 py-2 text-left text-xs hover:bg-gray-100 dark:hover:bg-gray-700 select-none cursor-pointer',
                    {
                      'bg-orange-50 dark:bg-orange-900/20':
                        step.type === TextTransformStepTypeEnum.FILTER,
                    },
                  )}
                >
                  Filter
                </button>
                <button
                  onClick={() => handleTypeChange(TextTransformStepTypeEnum.MAP)}
                  className={cn(
                    'block w-full px-3 py-2 text-left text-xs hover:bg-gray-100 dark:hover:bg-gray-700 select-none cursor-pointer',
                    {
                      'bg-purple-50 dark:bg-purple-900/20':
                        step.type === TextTransformStepTypeEnum.MAP,
                    },
                  )}
                >
                  Map
                </button>
              </div>
            )}
          </div>
        </div>
      </div>
      <CodeBox
        value={step.code}
        onChange={value => onUpdate({ code: value })}
        placeholder={
          step.type === TextTransformStepTypeEnum.FILTER
            ? '(element, index) => condition'
            : '(element, index) => transformed'
        }
      />
    </div>
  )
}

TransformStep.displayName = 'TransformStep'
