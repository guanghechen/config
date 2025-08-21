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
} from '@/shared/types'
import { TextTransformStepTypeEnum } from '@/shared/types'
import { useTextViewViewModel } from '../context'
import { SaveTransformerDialog } from './SaveTransformerDialog'

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

  // Sort transformers: 1. eventstream/jsonl first, 2. others without 'local.' prefix, 3. items with 'local.' prefix
  const sortedTransformers = React.useMemo(() => {
    const priority = transformers.filter(
      t => t.name === 'eventstream' || t.name === 'jsonl' || t.name === 'json-list',
    )
    const regular = transformers
      .filter(
        t =>
          t.name !== 'eventstream' &&
          t.name !== 'jsonl' &&
          t.name !== 'json-list' &&
          !t.name.startsWith('local.'),
      )
      .sort((a, b) => a.name.localeCompare(b.name))
    const local = transformers
      .filter(t => t.name.startsWith('local.'))
      .sort((a, b) => a.name.localeCompare(b.name))

    return { priority, regular, local }
  }, [transformers])

  const exportTransformData = async (): Promise<void> => {
    const exportData: ITextTransformExportData = {
      name: config.name,
      desc: config.desc,
      split: config.split,
      uuid: config.uuid,
      parents: config.parents,
      title: config.title,
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

      if (importedData.name) {
        updateTransformConfig({ name: importedData.name })
      }
      if (importedData.desc) {
        updateTransformConfig({ desc: importedData.desc })
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
      if (importedData.title) {
        updateTransformConfig({ title: importedData.title })
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
        {config.name ? `collection (${config.name})` : 'Collection'}
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
        {config.name ? `collection (${config.name})` : 'Collection'}
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
            <div className="max-h-80 overflow-y-auto space-y-1">
              {sortedTransformers.priority.map(transformer => (
                <button
                  key={transformer.name}
                  onClick={() => {
                    handleLoadTransformer(transformer.name).catch(console.error)
                  }}
                  className="block w-full px-3 py-2 text-left text-sm text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-700 cursor-pointer transition-colors duration-200"
                >
                  <div className="flex items-center justify-between">
                    <div className="font-medium">{transformer.name}</div>
                    {transformer.name === config.name && (
                      <svg
                        width="14"
                        height="14"
                        viewBox="0 0 24 24"
                        fill="none"
                        stroke="currentColor"
                        strokeWidth="2"
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        className="text-green-600 dark:text-green-400 flex-shrink-0"
                      >
                        <polyline points="20,6 9,17 4,12" />
                      </svg>
                    )}
                  </div>
                </button>
              ))}
              {sortedTransformers.priority.length > 0 &&
                (sortedTransformers.regular.length > 0 || sortedTransformers.local.length > 0) && (
                  <div className="border-t border-gray-200 dark:border-gray-600 my-2" />
                )}
              {sortedTransformers.regular.map(transformer => (
                <button
                  key={transformer.name}
                  onClick={() => {
                    handleLoadTransformer(transformer.name).catch(console.error)
                  }}
                  className="block w-full px-3 py-2 text-left text-sm text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-700 cursor-pointer transition-colors duration-200"
                >
                  <div className="flex items-center justify-between">
                    <div className="font-medium">{transformer.name}</div>
                    {transformer.name === config.name && (
                      <svg
                        width="14"
                        height="14"
                        viewBox="0 0 24 24"
                        fill="none"
                        stroke="currentColor"
                        strokeWidth="2"
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        className="text-green-600 dark:text-green-400 flex-shrink-0"
                      >
                        <polyline points="20,6 9,17 4,12" />
                      </svg>
                    )}
                  </div>
                </button>
              ))}
              {sortedTransformers.regular.length > 0 && sortedTransformers.local.length > 0 && (
                <div className="border-t border-gray-200 dark:border-gray-600 my-2" />
              )}
              {sortedTransformers.local.map(transformer => (
                <button
                  key={transformer.name}
                  onClick={() => {
                    handleLoadTransformer(transformer.name).catch(console.error)
                  }}
                  className="block w-full px-3 py-2 text-left text-sm text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-700 cursor-pointer transition-colors duration-200"
                >
                  <div className="flex items-center justify-between">
                    <div className="font-medium">{transformer.name}</div>
                    {transformer.name === config.name && (
                      <svg
                        width="14"
                        height="14"
                        viewBox="0 0 24 24"
                        fill="none"
                        stroke="currentColor"
                        strokeWidth="2"
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        className="text-green-600 dark:text-green-400 flex-shrink-0"
                      >
                        <polyline points="20,6 9,17 4,12" />
                      </svg>
                    )}
                  </div>
                </button>
              ))}
            </div>
          )}
        </div>
      </div>
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

CollectionDropdown.displayName = 'TextViewCollectionDropdown'
