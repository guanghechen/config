const STORAGE_CONFIG = {
  DATABASE_NAME: 'yoz',
  VERSION: 1,
  STORES: {
    CONTEXT: 'context',
    AUTH_TOKEN: 'auth_token',
    CACHE: 'cache',
  },
} as const

interface IStorageItem<T = any> {
  readonly key: string
  readonly value: T
  readonly timestamp: number
  readonly expiry?: number
}

interface IStorageOptions {
  readonly expiry?: number
}

class IndexedDBStorage {
  private static instance: IndexedDBStorage
  private db: IDBDatabase | null = null

  public static getInstance(): IndexedDBStorage {
    if (!IndexedDBStorage.instance) {
      IndexedDBStorage.instance = new IndexedDBStorage()
    }
    return IndexedDBStorage.instance
  }

  private async getDatabase(): Promise<IDBDatabase> {
    if (this.db) return this.db

    return new Promise((resolve, reject) => {
      const request = indexedDB.open(STORAGE_CONFIG.DATABASE_NAME, STORAGE_CONFIG.VERSION)

      request.onerror = () => reject(request.error)
      request.onsuccess = () => {
        this.db = request.result
        resolve(this.db)
      }

      request.onupgradeneeded = event => {
        const db = (event.target as IDBOpenDBRequest).result

        if (!db.objectStoreNames.contains(STORAGE_CONFIG.STORES.CONTEXT)) {
          const contextStore = db.createObjectStore(STORAGE_CONFIG.STORES.CONTEXT, {
            keyPath: 'key',
          })
          contextStore.createIndex('timestamp', 'timestamp', { unique: false })
        }

        if (!db.objectStoreNames.contains(STORAGE_CONFIG.STORES.AUTH_TOKEN)) {
          db.createObjectStore(STORAGE_CONFIG.STORES.AUTH_TOKEN, { keyPath: 'key' })
        }

        if (!db.objectStoreNames.contains(STORAGE_CONFIG.STORES.CACHE)) {
          const cacheStore = db.createObjectStore(STORAGE_CONFIG.STORES.CACHE, { keyPath: 'key' })
          cacheStore.createIndex('expiry', 'expiry', { unique: false })
        }
      }
    })
  }

  public async getItem<T = any>(storeName: string, key: string, fallback?: T): Promise<T | null> {
    try {
      const db = await this.getDatabase()
      const transaction = db.transaction([storeName], 'readonly')
      const store = transaction.objectStore(storeName)
      const request = store.get(key)

      const result = await new Promise<IStorageItem<T> | null>((resolve, reject) => {
        request.onsuccess = () => resolve(request.result || null)
        request.onerror = () => reject(request.error)
      })

      if (!result) return fallback ?? null

      if (result.expiry && Date.now() > result.expiry) {
        await this.removeItem(storeName, key)
        return fallback ?? null
      }

      return result.value
    } catch (error) {
      console.warn(`Failed to get item from ${storeName}:`, error)
      return fallback ?? null
    }
  }

  public async setItem<T = any>(
    storeName: string,
    key: string,
    value: T,
    options?: IStorageOptions,
  ): Promise<void> {
    try {
      const db = await this.getDatabase()
      const transaction = db.transaction([storeName], 'readwrite')
      const store = transaction.objectStore(storeName)

      const item: IStorageItem<T> = {
        key,
        value,
        timestamp: Date.now(),
        ...(options?.expiry && { expiry: Date.now() + options.expiry }),
      }

      const request = store.put(item)

      await new Promise<void>((resolve, reject) => {
        request.onsuccess = () => resolve()
        request.onerror = () => reject(request.error)
      })
    } catch (error) {
      console.warn(`Failed to set item in ${storeName}:`, error)
      throw error
    }
  }

  public async removeItem(storeName: string, key: string): Promise<void> {
    try {
      const db = await this.getDatabase()
      const transaction = db.transaction([storeName], 'readwrite')
      const store = transaction.objectStore(storeName)
      const request = store.delete(key)

      await new Promise<void>((resolve, reject) => {
        request.onsuccess = () => resolve()
        request.onerror = () => reject(request.error)
      })
    } catch (error) {
      console.warn(`Failed to remove item from ${storeName}:`, error)
      throw error
    }
  }

  public async cleanupExpired(): Promise<void> {
    try {
      const db = await this.getDatabase()
      const transaction = db.transaction([STORAGE_CONFIG.STORES.CACHE], 'readwrite')
      const store = transaction.objectStore(STORAGE_CONFIG.STORES.CACHE)
      const index = store.index('expiry')

      const now = Date.now()
      const range = IDBKeyRange.upperBound(now)
      const request = index.openCursor(range)

      request.onsuccess = event => {
        const cursor = (event.target as IDBRequest<IDBCursorWithValue>).result
        if (cursor) {
          cursor.delete()
          cursor.continue()
        }
      }

      await new Promise<void>((resolve, reject) => {
        transaction.oncomplete = () => resolve()
        transaction.onerror = () => reject(transaction.error)
      })
    } catch (error) {
      console.warn('Failed to cleanup expired items:', error)
    }
  }
}

export class UniversalStorage {
  private storage = IndexedDBStorage.getInstance()

  public async getContext<T = any>(key: string, fallback?: T): Promise<T | null> {
    return this.storage.getItem<T>(STORAGE_CONFIG.STORES.CONTEXT, key, fallback)
  }

  public async setContext<T = any>(key: string, value: T): Promise<void> {
    return this.storage.setItem<T>(STORAGE_CONFIG.STORES.CONTEXT, key, value)
  }

  public async removeContext(key: string): Promise<void> {
    return this.storage.removeItem(STORAGE_CONFIG.STORES.CONTEXT, key)
  }

  public async getAuthToken(): Promise<string | null> {
    return this.storage.getItem<string>(STORAGE_CONFIG.STORES.AUTH_TOKEN, 'auth_token')
  }

  public async setAuthToken(token: string): Promise<void> {
    return this.storage.setItem<string>(STORAGE_CONFIG.STORES.AUTH_TOKEN, 'auth_token', token)
  }

  public async removeAuthToken(): Promise<void> {
    return this.storage.removeItem(STORAGE_CONFIG.STORES.AUTH_TOKEN, 'auth_token')
  }

  public async getCache<T = any>(key: string, fallback?: T): Promise<T | null> {
    return this.storage.getItem<T>(STORAGE_CONFIG.STORES.CACHE, key, fallback)
  }

  public async setCache<T = any>(key: string, value: T, expiry?: number): Promise<void> {
    return this.storage.setItem<T>(STORAGE_CONFIG.STORES.CACHE, key, value, { expiry })
  }

  public async removeCache(key: string): Promise<void> {
    return this.storage.removeItem(STORAGE_CONFIG.STORES.CACHE, key)
  }

  public async cleanupExpired(): Promise<void> {
    return this.storage.cleanupExpired()
  }
}

export const universalStorage = new UniversalStorage()
