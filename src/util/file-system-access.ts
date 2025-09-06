import type { IFileHandle } from '../view/whiteboard/context/types'
import { universalStorage } from './storage'

// Consolidated type definitions
interface IFilePickerAcceptType {
  description?: string
  accept: Record<string, string[]>
}

interface IFilePickerOptions {
  types?: IFilePickerAcceptType[]
  multiple?: boolean
}

interface ISaveFilePickerOptions {
  suggestedName?: string
  types?: IFilePickerAcceptType[]
}

type PermissionState = 'granted' | 'denied' | 'prompt'

interface IExtendedFileSystemFileHandle extends FileSystemFileHandle {
  queryPermission?(descriptor?: { mode: 'read' | 'readwrite' }): Promise<PermissionState>
  requestPermission?(descriptor?: { mode: 'read' | 'readwrite' }): Promise<PermissionState>
}

declare global {
  interface Window {
    showOpenFilePicker?(options?: IFilePickerOptions): Promise<FileSystemFileHandle[]>
    showSaveFilePicker?(options?: ISaveFilePickerOptions): Promise<FileSystemFileHandle>
  }
}

interface IStoredHandle {
  readonly filename: string | null
  readonly handleKey: string
}

/**
 * Generates a default filename with the pattern 'whiteboard-<date>.<extension>'
 * @param extension - The file extension (without dot)
 * @returns A formatted filename string
 */
export const generateDefaultFilename = (extension: string): string => {
  const date = new Date()
  const year = date.getFullYear()
  const month = String(date.getMonth() + 1).padStart(2, '0')
  const day = String(date.getDate()).padStart(2, '0')
  return `whiteboard-${year}-${month}-${day}.${extension}`
}

// eslint-disable-next-line @typescript-eslint/no-extraneous-class
export class FileSystemAccessStorage {
  private static readonly STORAGE_PREFIX = 'fsHandle:'
  private static readonly handleStorage = new Map<string, FileSystemFileHandle>()

  private static generateHandleKey(): string {
    return `${Date.now()}_${Math.random().toString(36).substring(2)}`
  }

  private static async hasPermission(handle: FileSystemFileHandle): Promise<boolean> {
    try {
      const extendedHandle = handle as IExtendedFileSystemFileHandle
      if (typeof extendedHandle.queryPermission !== 'function') return true

      const permission = await extendedHandle.queryPermission({ mode: 'readwrite' })
      if (permission === 'granted') return true

      if (permission === 'prompt' && typeof extendedHandle.requestPermission === 'function') {
        const requested = await extendedHandle.requestPermission({ mode: 'readwrite' })
        return requested === 'granted'
      }
      return false
    } catch {
      return false
    }
  }

  public static isSupported(): boolean {
    return (
      typeof window !== 'undefined' &&
      typeof window.showOpenFilePicker === 'function' &&
      typeof window.showSaveFilePicker === 'function'
    )
  }

  public static async storeFileHandle(
    key: string,
    handle: FileSystemFileHandle,
    filename: string | null,
  ): Promise<void> {
    try {
      const handleKey = this.generateHandleKey()
      this.handleStorage.set(handleKey, handle)

      const storedData: IStoredHandle = { filename, handleKey }
      await universalStorage.setContext(this.STORAGE_PREFIX + key, storedData)
    } catch (error) {
      console.warn('Failed to store file handle:', error)
      throw error
    }
  }

  public static async getFileHandle(key: string): Promise<IFileHandle | null> {
    try {
      const stored = await universalStorage.getContext<IStoredHandle>(this.STORAGE_PREFIX + key)
      if (!stored) return { handle: null, filename: null }

      const handle = this.handleStorage.get(stored.handleKey) || null
      if (handle && !(await this.hasPermission(handle))) {
        this.handleStorage.delete(stored.handleKey)
        await this.removeFileHandle(key)
        return { handle: null, filename: stored.filename }
      }

      return { handle, filename: stored.filename }
    } catch (error) {
      console.warn('Failed to get file handle:', error)
      return { handle: null, filename: null }
    }
  }

  public static async removeFileHandle(key: string): Promise<void> {
    try {
      const stored = await universalStorage.getContext<IStoredHandle>(this.STORAGE_PREFIX + key)
      if (stored) this.handleStorage.delete(stored.handleKey)
      await universalStorage.removeContext(this.STORAGE_PREFIX + key)
    } catch (error) {
      console.warn('Failed to remove file handle:', error)
    }
  }

  public static async selectFile(options?: {
    types?: IFilePickerAcceptType[]
    multiple?: boolean
  }): Promise<FileSystemFileHandle[]> {
    if (!this.isSupported()) {
      throw new Error('File System Access API is not supported')
    }

    const defaultTypes = [
      {
        description: 'Text files',
        accept: {
          'text/*': ['.txt', '.md', '.json', '.html', '.svg', '.excalidraw', '.drawboard'],
        },
      },
    ]

    return window.showOpenFilePicker!({
      multiple: options?.multiple || false,
      types: options?.types || defaultTypes,
    })
  }

  public static async saveFile(
    content: string,
    options?: {
      suggestedName?: string
      types?: IFilePickerAcceptType[]
      existingHandle?: FileSystemFileHandle
    },
  ): Promise<FileSystemFileHandle> {
    if (!this.isSupported()) {
      throw new Error('File System Access API is not supported')
    }

    let fileHandle: FileSystemFileHandle

    if (options?.existingHandle) {
      fileHandle = options.existingHandle
    } else {
      const defaultTypes = [
        {
          description: 'Text files',
          accept: {
            'text/*': ['.txt', '.md', '.json', '.html', '.svg', '.excalidraw', '.drawboard'],
          },
        },
      ]

      const types = options?.types || defaultTypes
      let suggestedName = options?.suggestedName

      if (!suggestedName) {
        const firstType = types[0]
        const extensions = firstType?.accept ? Object.values(firstType.accept)[0] : undefined
        const extension = extensions?.[0]?.replace('.', '') || 'txt'
        suggestedName = generateDefaultFilename(extension)
      }

      fileHandle = await window.showSaveFilePicker!({ suggestedName, types })
    }

    const writable = await fileHandle.createWritable()
    await writable.write(content)
    await writable.close()

    return fileHandle
  }

  public static async readFile(handle: FileSystemFileHandle): Promise<string> {
    const file = await handle.getFile()
    return await file.text()
  }
}
