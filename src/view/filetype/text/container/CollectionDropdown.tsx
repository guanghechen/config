import { useStateValue } from '@guanghechen/react-viewmodel'
import cn from 'clsx'
import React from 'react'
import { toast } from 'react-toastify'
import { useGetTransformerList } from '@/hook/api/transform/text/list'
import { useGetTransformer } from '@/hook/api/transform/text/load'
import { usePostTransformer } from '@/hook/api/transform/text/save'
import type {
  ITextTransformConfig,
  ITextTransformExportData,
  ITextTransformStep,
  ITextTransformStepData,
} from '@/shared/transform/types'
import { TextTransformStepTypeEnum } from '@/shared/transform/types'
import { useTextViewViewModel } from '../context'

interface IProps {
  readonly isOpen: boolean
  readonly onClose: () => void
  readonly onToggle: () => void
}

export const CollectionDropdown: React.FC<IProps> = ({ isOpen, onClose, onToggle }) => {
  const viewmodel = useTextViewViewModel()
  const config: ITextTransformConfig = useStateValue(viewmodel.transformConfig$)

  const {
    refresh: refreshTransformerList,
    loading: loadingTransformerList,
    transformers,
  } = useGetTransformerList()
  const { save: saveTransformer, loading: savingTransformer } = usePostTransformer()
  const { load: loadTransformer } = useGetTransformer()

  const [showSaveDialog, setShowSaveDialog] = React.useState(false)
  const dropdownRef = React.useRef<HTMLDivElement>(null)
  const saveButtonRef = React.useRef<HTMLButtonElement>(null)

  // Close dropdown when clicking outside (but not when save dialog is open)
  React.useEffect(() => {
    const handleClickOutside = (event: MouseEvent): void => {
      if (showSaveDialog) return // Don't close dropdown when save dialog is open
      if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
        onClose()
      }
    }

    if (isOpen) {
      document.addEventListener('mousedown', handleClickOutside)
      return () => document.removeEventListener('mousedown', handleClickOutside)
    }
  }, [isOpen, onClose, showSaveDialog])

  // Fetch transformer list when dropdown opens
  React.useEffect(() => {
    if (!isOpen) return
    void refreshTransformerList()
  }, [isOpen, refreshTransformerList])

  const handleSave = async (name: string): Promise<void> => {
    try {
      await saveTransformer(name, config)
      toast.success('Transformer saved successfully!')
      setShowSaveDialog(false)
      // Refresh the list
      void refreshTransformerList()
    } catch (error) {
      toast.error('Failed to save transformer')
      console.error('Error saving transformer:', error)
    }
  }

  const handleDirectSave = async (): Promise<void> => {
    if (!config.name || config.name.trim() === 'unnamed') {
      toast.error('Please set a transformer name first before saving')
      return
    }

    try {
      await saveTransformer(config.name, config)
      toast.success(`Transformer "${config.name}" saved successfully!`)
      // Refresh the list
      void refreshTransformerList()
    } catch (error) {
      toast.error('Failed to save transformer')
      console.error('Error saving transformer:', error)
    }
  }

  const handleLoadTransformer = async (name: string): Promise<void> => {
    try {
      const loadedConfig = await loadTransformer(name)
      viewmodel.transformConfig$.next(loadedConfig)
      toast.success(`Transformer "${name}" loaded successfully!`)
      onClose()
    } catch (error) {
      toast.error('Failed to load transformer')
      console.error('Error loading transformer:', error)
    }
  }

  const exportTransformData = async (): Promise<void> => {
    const exportData: ITextTransformExportData = {
      name: config.name,
      split: config.split,
      uuid: config.uuid,
      parents: config.parents,
      steps: config.steps.map(step => ({
        skip: step.skip ?? false,
        code: step.code,
        type: step.type,
      })),
    }

    try {
      await navigator.clipboard.writeText(JSON.stringify(exportData, null, 2))
      toast.success('Transform data copied to clipboard successfully!')
    } catch (err) {
      console.error('Failed to copy to clipboard:', err)
      toast.error('Failed to copy to clipboard')
    }
  }

  const importTransformData = async (): Promise<void> => {
    try {
      const clipboardText = await navigator.clipboard.readText()

      if (!clipboardText.trim()) {
        toast.error('Clipboard is empty')
        return
      }

      const importedData: ITextTransformExportData = JSON.parse(clipboardText)

      const updateTransformConfig = (updates: Partial<ITextTransformConfig>): void => {
        const current = viewmodel.transformConfig$.getSnapshot()
        viewmodel.transformConfig$.next({ ...current, ...updates })
      }

      if (importedData.split) {
        updateTransformConfig({ split: importedData.split })
      }
      if (importedData.uuid) {
        updateTransformConfig({ uuid: importedData.uuid })
      }
      if (importedData.parents) {
        updateTransformConfig({ parents: importedData.parents })
      }
      if (importedData.steps && Array.isArray(importedData.steps)) {
        const steps: ITextTransformStep[] = importedData.steps.map(
          (transformer: ITextTransformStepData, index: number): ITextTransformStep => {
            const functionCode = transformer.code || ''
            const importedType = transformer.type || TextTransformStepTypeEnum.MAP

            return {
              id: `imported-${Date.now()}-${index}`,
              type: importedType,
              code: functionCode,
              skip: transformer.skip ?? false,
            }
          },
        )
        updateTransformConfig({ steps })
      }

      toast.success('Transform data imported successfully!')
    } catch (err) {
      console.error('Failed to import from clipboard:', err)
      toast.error('Failed to import: Invalid JSON format')
    }
  }

  if (!isOpen) {
    return (
      <button
        onClick={onToggle}
        className="flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium text-gray-700 dark:text-gray-300 hover:text-gray-900 dark:hover:text-gray-100 hover:bg-gray-100 dark:hover:bg-gray-700 rounded transition-colors duration-200 cursor-pointer"
        title="Collection"
      >
        <svg
          width="14"
          height="14"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth="2"
          strokeLinecap="round"
          strokeLinejoin="round"
        >
          <rect x="3" y="3" width="18" height="18" rx="2" ry="2" />
          <line x1="12" y1="8" x2="12" y2="16" />
          <line x1="8" y1="12" x2="16" y2="12" />
        </svg>
        Collection
        <svg
          width="14"
          height="14"
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
    )
  }

  return (
    <div className="relative">
      <button
        onClick={onToggle}
        className="flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium text-gray-700 dark:text-gray-300 hover:text-gray-900 dark:hover:text-gray-100 hover:bg-gray-100 dark:hover:bg-gray-700 rounded transition-colors duration-200 cursor-pointer"
        title="Collection"
      >
        <svg
          width="14"
          height="14"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth="2"
          strokeLinecap="round"
          strokeLinejoin="round"
        >
          <rect x="3" y="3" width="18" height="18" rx="2" ry="2" />
          <line x1="12" y1="8" x2="12" y2="16" />
          <line x1="8" y1="12" x2="16" y2="12" />
        </svg>
        Collection
        <svg
          width="14"
          height="14"
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

      <div
        ref={dropdownRef}
        className="absolute right-0 top-full mt-1 w-64 bg-white dark:bg-gray-800 border border-gray-300 dark:border-gray-600 rounded-lg shadow-lg z-50"
      >
        {/* Action Section */}
        <div className="p-3 border-b border-gray-200 dark:border-gray-600">
          <div className="space-y-1">
            <button
              onClick={() => {
                handleDirectSave().catch(console.error)
              }}
              disabled={savingTransformer || !config.name || config.name.trim() === 'unnamed'}
              className={cn(
                'block w-full px-3 py-2 text-left text-sm cursor-pointer transition-colors duration-200',
                savingTransformer || !config.name || config.name.trim() === 'unnamed'
                  ? 'text-gray-400 dark:text-gray-500 cursor-not-allowed'
                  : 'text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-700',
              )}
            >
              <div className="flex items-center gap-2">
                <svg
                  width="14"
                  height="14"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="2"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                >
                  <path d="M19 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11l5 5v11a2 2 0 0 1-2 2z" />
                  <polyline points="17,21 17,13 7,13 7,21" />
                  <polyline points="7,3 7,8 15,8" />
                </svg>
                {savingTransformer ? 'Saving...' : `Save (${config.name})`}
              </div>
            </button>
            <button
              ref={saveButtonRef}
              onClick={() => {
                setShowSaveDialog(true)
                // Don't close dropdown - keep it open while showing the dialog
              }}
              className="block w-full px-3 py-2 text-left text-sm text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-700 cursor-pointer transition-colors duration-200"
            >
              <div className="flex items-center gap-2">
                <svg
                  width="14"
                  height="14"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="2"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                >
                  <path d="M19 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11l5 5v11a2 2 0 0 1-2 2z" />
                  <polyline points="17,21 17,13 7,13 7,21" />
                  <polyline points="7,3 7,8 15,8" />
                </svg>
                Save as
              </div>
            </button>
            <button
              onClick={() => {
                importTransformData().catch(console.error)
              }}
              className="block w-full px-3 py-2 text-left text-sm text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-700 cursor-pointer transition-colors duration-200"
            >
              <div className="flex items-center gap-2">
                <svg
                  width="14"
                  height="14"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="2"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                >
                  <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
                  <polyline points="7,10 12,15 17,10" />
                  <line x1="12" y1="15" x2="12" y2="3" />
                </svg>
                Import from clipboard
              </div>
            </button>
            <button
              onClick={() => {
                exportTransformData().catch(console.error)
              }}
              className="block w-full px-3 py-2 text-left text-sm text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-700 cursor-pointer transition-colors duration-200"
            >
              <div className="flex items-center gap-2">
                <svg
                  width="14"
                  height="14"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="2"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                >
                  <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
                  <polyline points="17,8 12,3 7,8" />
                  <line x1="12" y1="3" x2="12" y2="15" />
                </svg>
                Export to clipboard
              </div>
            </button>
          </div>
        </div>

        {/* List Section */}
        <div className="p-3">
          {loadingTransformerList ? (
            <div className="text-sm text-gray-500 dark:text-gray-400 text-center py-2">
              Loading...
            </div>
          ) : transformers.length === 0 ? (
            <div className="text-sm text-gray-500 dark:text-gray-400 text-center py-2">
              No saved transformers
            </div>
          ) : (
            <div className="max-h-40 overflow-y-auto space-y-1">
              {transformers.map(transformer => (
                <button
                  key={transformer.name}
                  onClick={() => {
                    handleLoadTransformer(transformer.name).catch(console.error)
                  }}
                  className="block w-full px-3 py-2 text-left text-sm text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-700 cursor-pointer transition-colors duration-200"
                >
                  <div className="font-medium">{transformer.name}</div>
                </button>
              ))}
            </div>
          )}
        </div>
      </div>

      {/* Save Transformer Dialog */}
      {showSaveDialog && (
        <SaveTransformerDialog
          onSave={handleSave}
          onClose={() => setShowSaveDialog(false)}
          isSaving={savingTransformer}
          saveButtonRef={saveButtonRef}
        />
      )}
    </div>
  )
}

interface ISaveTransformerDialogProps {
  readonly onSave: (name: string) => Promise<void>
  readonly onClose: () => void
  readonly isSaving: boolean
  readonly saveButtonRef: React.RefObject<HTMLButtonElement | null>
}

const SaveTransformerDialog: React.FC<ISaveTransformerDialogProps> = ({
  onSave,
  onClose,
  isSaving,
  saveButtonRef,
}) => {
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

CollectionDropdown.displayName = 'CollectionDropdown'
