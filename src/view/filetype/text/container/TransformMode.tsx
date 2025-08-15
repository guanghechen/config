import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { toast } from 'react-toastify'
import { useTextViewViewModel } from '../context'
import type {
  ITransformConfig,
  ITransformExportData,
  ITransformerFunction,
  ITransformerFunctionData,
} from '../context/types'
import { transformTextToNodes } from '../util/transform'
import { CodeBox } from './CodeBox'
import { TransformerItem } from './TransformerItem'

interface ITooltipProps {
  readonly content: string
  readonly children: React.ReactNode
}

const Tooltip: React.FC<ITooltipProps> = ({ content, children }) => {
  const [isVisible, setIsVisible] = React.useState(false)

  return (
    <div className="relative inline-block">
      <div onMouseEnter={() => setIsVisible(true)} onMouseLeave={() => setIsVisible(false)}>
        {children}
      </div>
      {isVisible && (
        <div className="absolute bottom-full left-1/2 transform -translate-x-1/2 mb-2 px-3 py-2 text-xs text-white bg-gray-900 dark:bg-gray-200 dark:text-gray-900 rounded-lg shadow-lg whitespace-nowrap z-10 max-w-xs break-words">
          <div className="text-center">{content}</div>
          <div className="absolute top-full left-1/2 transform -translate-x-1/2 border-4 border-transparent border-t-gray-900 dark:border-t-gray-200" />
        </div>
      )}
    </div>
  )
}

export const TransformMode: React.FC = () => {
  const viewmodel = useTextViewViewModel()
  const transformConfig: ITransformConfig = useStateValue(viewmodel.transformConfig$)
  const content: string | null = useStateValue(viewmodel.content$)
  const [dropdownOpen, setDropdownOpen] = React.useState(false)
  const [isDragging, setIsDragging] = React.useState(false)

  const updateTransformConfig = (updates: Partial<ITransformConfig>): void => {
    const current = viewmodel.transformConfig$.getSnapshot()
    viewmodel.transformConfig$.next({ ...current, ...updates })
  }

  const addTransformerFunction = (type: 'filter' | 'map'): void => {
    const current = transformConfig.transformers
    const newFunction: ITransformerFunction = {
      id: `${type}-${Date.now()}`,
      type,
      function:
        type === 'filter'
          ? '(element, index, elements) => element.trim().length > 0'
          : '(element, index, elements) => element.trim()',
    }
    updateTransformConfig({ transformers: [...current, newFunction] })
  }

  const removeTransformerFunction = (id: string): void => {
    const current = transformConfig.transformers
    updateTransformConfig({ transformers: current.filter(func => func.id !== id) })
  }

  const updateTransformerFunction = (id: string, updates: Partial<ITransformerFunction>): void => {
    const current = transformConfig.transformers
    const updated = current.map(func => (func.id === id ? { ...func, ...updates } : func))
    updateTransformConfig({ transformers: updated })
  }

  const moveFunction = (id: string, direction: 'up' | 'down'): void => {
    const current = transformConfig.transformers
    const index = current.findIndex(func => func.id === id)
    if (index === -1) return

    const newIndex = direction === 'up' ? index - 1 : index + 1
    if (newIndex < 0 || newIndex >= current.length) return

    const updated = [...current]
    const [moved] = updated.splice(index, 1)
    updated.splice(newIndex, 0, moved)
    updateTransformConfig({ transformers: updated })
  }

  const handleDragStart = (_index: number): void => {
    setIsDragging(true)
  }

  const handleDragOver = (_index: number): void => {
    // Optional: could add visual feedback here
  }

  const handleDrop = (fromIndex: number, toIndex: number): void => {
    if (fromIndex === toIndex) {
      setIsDragging(false)
      return
    }

    const current = transformConfig.transformers
    const updated = [...current]
    const [draggedItem] = updated.splice(fromIndex, 1)
    updated.splice(toIndex, 0, draggedItem)

    updateTransformConfig({ transformers: updated })
    setIsDragging(false)
  }

  const exportTransformData = async (): Promise<void> => {
    const exportData: ITransformExportData = {
      split: transformConfig.split,
      uuid: transformConfig.uuidFunction,
      parent_uuid: transformConfig.parentUuidFunction,
      transformers: transformConfig.transformers.map(transformer => ({
        skip: transformer.skipped || false,
        code: transformer.function,
        type: transformer.type,
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

  const executeTransform = (): void => {
    if (!content) {
      toast.error('No content to transform')
      return
    }

    const result = transformTextToNodes(content, transformConfig)

    if (result.error) {
      toast.error(result.error)
      viewmodel.transformedNodes$.next([])
    } else {
      viewmodel.transformedNodes$.next(result.nodes)
      toast.success(`Transform completed: ${result.nodes.length} nodes generated`)
    }
  }

  const importTransformData = async (): Promise<void> => {
    try {
      const clipboardText = await navigator.clipboard.readText()

      if (!clipboardText.trim()) {
        toast.error('Clipboard is empty')
        return
      }

      const importedData: ITransformExportData = JSON.parse(clipboardText)

      if (importedData.split) {
        updateTransformConfig({ split: importedData.split })
      }
      if (importedData.uuid) {
        updateTransformConfig({ uuidFunction: importedData.uuid })
      }
      if (importedData.parent_uuid) {
        updateTransformConfig({ parentUuidFunction: importedData.parent_uuid })
      }
      if (importedData.transformers && Array.isArray(importedData.transformers)) {
        const transformerFunctions: ITransformerFunction[] = importedData.transformers.map(
          (transformer: ITransformerFunctionData, index: number) => {
            const functionCode = transformer.code || ''
            const importedType = transformer.type || 'map'

            return {
              id: `imported-${Date.now()}-${index}`,
              type: importedType,
              function: functionCode,
              skipped:
                transformer.skip !== undefined
                  ? transformer.skip
                  : (transformer as any).skipped || false,
            }
          },
        )
        updateTransformConfig({ transformers: transformerFunctions })
      }

      toast.success('Transform data imported successfully!')
    } catch (err) {
      console.error('Failed to import from clipboard:', err)
      toast.error('Failed to import: Invalid JSON format')
    }
  }

  return (
    <div className="w-full space-y-0">
      {/* Header Bar */}
      <div className="flex items-center justify-between p-4 bg-gray-50 dark:bg-gray-800/50">
        <h2 className="text-lg font-semibold text-gray-800 dark:text-gray-200">Transform View</h2>
        <div className="flex items-center gap-2">
          <button
            onClick={executeTransform}
            className="px-3 py-1.5 bg-purple-500 text-white rounded hover:bg-purple-600 dark:bg-purple-600 dark:hover:bg-purple-500 text-sm font-medium cursor-pointer"
          >
            Run
          </button>
          <button
            onClick={() => {
              importTransformData().catch(console.error)
            }}
            className="px-3 py-1.5 bg-green-500 text-white rounded hover:bg-green-600 dark:bg-green-600 dark:hover:bg-green-500 text-sm font-medium cursor-pointer"
          >
            Import
          </button>
          <button
            onClick={() => {
              exportTransformData().catch(console.error)
            }}
            className="px-3 py-1.5 bg-blue-500 text-white rounded hover:bg-blue-600 dark:bg-blue-600 dark:hover:bg-blue-500 text-sm font-medium cursor-pointer"
          >
            Export
          </button>
        </div>
      </div>

      {/* Split Line */}
      <div className="border-b border-gray-200 dark:border-gray-700" />

      {/* Identifiers Section */}
      <div className="bg-purple-50 dark:bg-purple-900/40 p-6 border-l-4 border-purple-500 dark:border-purple-400">
        <h3 className="text-lg font-semibold text-purple-800 dark:text-purple-300 mb-4">
          Identifiers
        </h3>
        <div className="flex flex-col gap-4">
          <div>
            <div className="flex items-center gap-2 mb-2">
              <span className="block text-sm font-medium text-gray-700 dark:text-gray-300">
                UUID Function
              </span>
              <Tooltip content="Function to generate unique ID for each item">
                <span className="w-4 h-4 bg-purple-500 text-white rounded-full text-xs flex items-center justify-center cursor-help select-none">
                  ?
                </span>
              </Tooltip>
            </div>
            <CodeBox
              value={transformConfig.uuidFunction}
              onChange={value => updateTransformConfig({ uuidFunction: value })}
              placeholder="(item, index) => 'item-' + index"
            />
          </div>
          <div>
            <div className="flex items-center gap-2 mb-2">
              <span className="block text-sm font-medium text-gray-700 dark:text-gray-300">
                Parent UUID Function
              </span>
              <Tooltip content="Function to generate parent ID for each item">
                <span className="w-4 h-4 bg-purple-500 text-white rounded-full text-xs flex items-center justify-center cursor-help select-none">
                  ?
                </span>
              </Tooltip>
            </div>
            <CodeBox
              value={transformConfig.parentUuidFunction}
              onChange={value => updateTransformConfig({ parentUuidFunction: value })}
              placeholder="() => null"
            />
          </div>
        </div>
      </div>

      {/* Split Section */}
      <div className="bg-blue-50 dark:bg-blue-900/40 p-6 border-l-4 border-blue-500 dark:border-blue-400">
        <div className="flex items-center gap-2 mb-4">
          <h3 className="text-lg font-semibold text-blue-800 dark:text-blue-300">Split</h3>
          <Tooltip content="Regex pattern (e.g., /\n/) or arrow function (e.g., (text) => text.split('\n'))">
            <span className="w-4 h-4 bg-blue-500 text-white rounded-full text-xs flex items-center justify-center cursor-help select-none">
              ?
            </span>
          </Tooltip>
        </div>
        <CodeBox
          value={transformConfig.split}
          onChange={value => updateTransformConfig({ split: value })}
          placeholder="/\\n/"
          description="Split Function"
        />
      </div>

      {/* Filter/Map Section */}
      <div className="bg-green-50 dark:bg-green-900/40 p-6 border-l-4 border-green-500 dark:border-green-400">
        <div className="space-y-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <h3 className="text-lg font-semibold text-green-800 dark:text-green-300">
                Transformers
              </h3>
              <Tooltip content="Chain of functions to process the split results. Order matters - functions execute top to bottom.">
                <span className="w-4 h-4 bg-green-500 text-white rounded-full text-xs flex items-center justify-center cursor-help select-none">
                  ?
                </span>
              </Tooltip>
            </div>
            <div className="relative inline-block">
              <div className="flex items-stretch">
                <button
                  onClick={() => addTransformerFunction('map')}
                  className="rounded-l bg-purple-500 px-3 py-1 text-xs text-white hover:bg-purple-600 dark:bg-purple-600 dark:hover:bg-purple-500 select-none cursor-pointer"
                >
                  Add Transformer
                </button>
                <div className="relative flex">
                  <button
                    onClick={() => setDropdownOpen(!dropdownOpen)}
                    className="rounded-r bg-purple-500 px-2 py-1 text-xs text-white hover:bg-purple-600 dark:bg-purple-600 dark:hover:bg-purple-500 select-none border-l border-purple-400 dark:border-purple-500 flex items-center cursor-pointer"
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
                  {dropdownOpen && (
                    <div className="absolute right-0 top-full mt-1 min-w-32 bg-white dark:bg-gray-800 border border-gray-300 dark:border-gray-600 rounded shadow-lg z-10">
                      <button
                        onClick={() => {
                          addTransformerFunction('map')
                          setDropdownOpen(false)
                        }}
                        className="block w-full px-3 py-2 text-left text-xs text-gray-700 dark:text-gray-300 hover:bg-purple-50 dark:hover:bg-purple-900/20 cursor-pointer"
                      >
                        Add Map
                      </button>
                      <button
                        onClick={() => {
                          addTransformerFunction('filter')
                          setDropdownOpen(false)
                        }}
                        className="block w-full px-3 py-2 text-left text-xs text-gray-700 dark:text-gray-300 hover:bg-orange-50 dark:hover:bg-orange-900/20 cursor-pointer"
                      >
                        Add Filter
                      </button>
                    </div>
                  )}
                </div>
              </div>
            </div>
          </div>
          {transformConfig.transformers.length === 0 ? (
            <div className="rounded border-2 border-dashed border-gray-300 dark:border-gray-600 bg-gray-50/50 dark:bg-gray-700/30 p-4 text-center text-sm text-gray-500 dark:text-gray-400">
              No transformer functions. Click "Add Transformer" or use the dropdown to add
              functions.
            </div>
          ) : (
            <div className={`space-y-3 ${isDragging ? 'select-none' : ''}`}>
              {transformConfig.transformers.map((func, index) => (
                <TransformerItem
                  key={func.id}
                  func={func}
                  index={index}
                  totalCount={transformConfig.transformers.length}
                  onUpdate={updates => updateTransformerFunction(func.id, updates)}
                  onRemove={() => removeTransformerFunction(func.id)}
                  onMoveUp={() => moveFunction(func.id, 'up')}
                  onMoveDown={() => moveFunction(func.id, 'down')}
                  onDragStart={handleDragStart}
                  onDragOver={handleDragOver}
                  onDrop={handleDrop}
                />
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  )
}

TransformMode.displayName = 'TransformMode'
