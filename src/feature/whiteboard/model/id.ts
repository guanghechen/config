export type IWhiteboardEntityType = 'doc' | 'node' | 'port' | 'edge' | 'event' | 'command' | 'trace'

const NANOID_ALPHABET = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz-'
const NANOID_DEFAULT_SIZE = 12

const createRandomBytes = (size: number): Uint8Array => {
  if (globalThis.crypto && typeof globalThis.crypto.getRandomValues === 'function') {
    return globalThis.crypto.getRandomValues(new Uint8Array(size))
  }

  const bytes = new Uint8Array(size)
  for (let i = 0; i < size; i += 1) {
    bytes[i] = Math.floor(Math.random() * 256)
  }

  return bytes
}

export const createNanoId = (size: number = NANOID_DEFAULT_SIZE): string => {
  const bytes = createRandomBytes(size)
  let result = ''

  for (let i = 0; i < bytes.length; i += 1) {
    const index = bytes[i] % NANOID_ALPHABET.length
    result += NANOID_ALPHABET[index]
  }

  return result
}

const createEntityId = (type: IWhiteboardEntityType): string => {
  return `${type}-${createNanoId()}`
}

export const IdFactory = {
  createDocId: (): string => createEntityId('doc'),
  createNodeId: (): string => createEntityId('node'),
  createPortId: (): string => createEntityId('port'),
  createEdgeId: (): string => createEntityId('edge'),
  createEventId: (): string => createEntityId('event'),
  createCommandId: (): string => createEntityId('command'),
  createTraceId: (): string => createEntityId('trace'),
} as const
