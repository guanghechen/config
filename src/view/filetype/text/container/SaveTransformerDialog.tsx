import cn from 'clsx'
import React from 'react'
import { toast } from 'react-toastify'

interface IProps {
  readonly isSaving: boolean
  readonly saveButtonRef: React.RefObject<HTMLButtonElement | null>
  readonly onSave: (name: string) => Promise<void>
  readonly onClose: () => void
}

export const SaveTransformerDialog: React.FC<IProps> = props => {
  const { onSave, onClose, isSaving, saveButtonRef } = props
  const [name, setName] = React.useState('')
  const [position, setPosition] = React.useState<{ top: number; left: number }>({ top: 0, left: 0 })
  const inputRef = React.useRef<HTMLInputElement>(null)
  const dialogRef = React.useRef<HTMLDivElement>(null)

  // Calculate position relative to save button
  React.useEffect(() => {
    if (saveButtonRef.current) {
      const buttonRect = saveButtonRef.current.getBoundingClientRect()
      const scrollX = window.pageXOffset || document.documentElement.scrollLeft
      const scrollY = window.pageYOffset || document.documentElement.scrollTop

      setPosition({
        top: buttonRect.bottom + scrollY + 8, // 8px gap below button
        left: buttonRect.left + scrollX,
      })
    }
  }, [saveButtonRef])

  // Auto-focus the input when dialog opens
  React.useEffect(() => {
    if (inputRef.current) {
      inputRef.current.focus()
    }
  }, [])

  // Handle escape key to close dialog
  React.useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent): void => {
      if (event.key === 'Escape') {
        onClose()
      }
    }

    document.addEventListener('keydown', handleKeyDown)
    return () => document.removeEventListener('keydown', handleKeyDown)
  }, [onClose])

  // Handle click outside to close dialog
  React.useEffect(() => {
    const handleClickOutside = (event: MouseEvent): void => {
      if (dialogRef.current && !dialogRef.current.contains(event.target as Node)) {
        onClose()
      }
    }

    document.addEventListener('mousedown', handleClickOutside)
    return () => document.removeEventListener('mousedown', handleClickOutside)
  }, [onClose])

  const handleSave = async (): Promise<void> => {
    if (!name.trim()) {
      toast.error('Please enter a name for the transformer')
      return
    }
    await onSave(name.trim())
  }

  const handleSubmit = (e: React.FormEvent): void => {
    e.preventDefault()
    if (!isSaving) {
      handleSave().catch(console.error)
    }
  }

  return (
    <div
      ref={dialogRef}
      className="fixed z-50 bg-white dark:bg-gray-800 border border-gray-300 dark:border-gray-600 rounded-lg shadow-lg min-w-64"
      style={{
        top: position.top,
        left: position.left,
      }}
    >
      <div className="p-4">
        <div className="flex items-center justify-between mb-3">
          <h3 className="text-sm font-medium text-gray-900 dark:text-gray-100">Save As</h3>
          <button
            onClick={onClose}
            className="text-gray-400 dark:text-gray-500 hover:text-gray-600 dark:hover:text-gray-300 transition-colors"
            disabled={isSaving}
          >
            <svg
              width="16"
              height="16"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
              strokeLinecap="round"
              strokeLinejoin="round"
            >
              <line x1="18" y1="6" x2="6" y2="18" />
              <line x1="6" y1="6" x2="18" y2="18" />
            </svg>
          </button>
        </div>

        <form onSubmit={handleSubmit}>
          <div className="mb-3">
            <input
              ref={inputRef}
              type="text"
              value={name}
              onChange={e => setName(e.target.value)}
              placeholder="Enter transformer name..."
              className="w-full px-3 py-2 text-sm border border-gray-300 dark:border-gray-600 rounded bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100 placeholder-gray-500 dark:placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-orange-500 dark:focus:ring-orange-400"
              disabled={isSaving}
            />
          </div>

          <div className="flex gap-2 justify-end">
            <button
              type="button"
              onClick={onClose}
              disabled={isSaving}
              className="px-3 py-1.5 text-sm font-medium text-gray-700 dark:text-gray-300 bg-gray-100 dark:bg-gray-700 hover:bg-gray-200 dark:hover:bg-gray-600 rounded transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={!name.trim() || isSaving}
              className={cn(
                'px-3 py-1.5 text-sm font-medium rounded transition-colors',
                !name.trim() || isSaving
                  ? 'bg-gray-300 dark:bg-gray-600 text-gray-500 dark:text-gray-400 cursor-not-allowed'
                  : 'bg-orange-500 dark:bg-orange-600 text-white hover:bg-orange-600 dark:hover:bg-orange-700',
              )}
            >
              {isSaving ? 'Saving...' : 'Save'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}

SaveTransformerDialog.displayName = 'TextViewSaveTransformerDialog'
