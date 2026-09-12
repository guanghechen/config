import { MAX_IMAGE_FILE_BYTES, MAX_IMAGE_URL_LENGTH, rasterMime } from '@/shared/whiteboard/images'
import type { IImportedImage } from '@/shared/whiteboard/images'

function readDataUrl(blob: Blob, signal: AbortSignal): Promise<string> {
  return new Promise((resolve, reject) => {
    signal.throwIfAborted()
    const reader = new FileReader()
    const abort = (): void => reader.abort()
    signal.addEventListener('abort', abort, { once: true })
    reader.onload = () => resolve(String(reader.result))
    reader.onerror = () => reject(reader.error ?? new Error('Unable to read image'))
    reader.onabort = () => reject(signal.reason)
    reader.onloadend = () => signal.removeEventListener('abort', abort)
    reader.readAsDataURL(blob)
  })
}

export async function importImage(file: File, signal: AbortSignal): Promise<IImportedImage> {
  if (!file.size || file.size > MAX_IMAGE_FILE_BYTES)
    throw new Error(`${file.name}: images must be between 1 byte and 20 MB`)
  const header = new Uint8Array(await file.slice(0, 32).arrayBuffer())
  const mime = rasterMime(header)
  signal.throwIfAborted()
  if (!mime) throw new Error(`${file.name}: choose a PNG, JPEG, WebP or GIF image`)
  const blob = file.slice(0, file.size, mime)
  let bitmap: ImageBitmap
  try {
    bitmap = await createImageBitmap(blob)
  } catch {
    signal.throwIfAborted()
    throw new Error(`${file.name}: unable to decode image`)
  }
  try {
    signal.throwIfAborted()
    if (!bitmap.width || !bitmap.height || bitmap.width * bitmap.height > 40_000_000)
      throw new Error(`${file.name}: image exceeds the 40 megapixel limit`)
    const oversized = bitmap.width > 4096 || bitmap.height > 4096
    if (!oversized && Math.ceil(file.size / 3) * 4 + 32 <= MAX_IMAGE_URL_LENGTH) {
      const url = await readDataUrl(blob, signal)
      signal.throwIfAborted()
      return { url, width: bitmap.width, height: bitmap.height, optimized: false }
    }
    if (
      mime === 'image/gif' ||
      (mime === 'image/webp' &&
        String.fromCharCode(...header.subarray(12, 16)) === 'VP8X' &&
        header[20] & 2)
    )
      throw new Error(
        `${file.name}: animated image is too large to embed; use a smaller file or an image URL`,
      )
    const canvas = document.createElement('canvas')
    try {
      let scale = Math.min(1, 2048 / Math.max(bitmap.width, bitmap.height))
      for (let attempt = 0; attempt < 5; attempt++) {
        signal.throwIfAborted()
        canvas.width = Math.max(1, Math.round(bitmap.width * scale))
        canvas.height = Math.max(1, Math.round(bitmap.height * scale))
        const context = canvas.getContext('2d')
        if (!context) throw new Error('Image conversion is unavailable in this browser')
        context.drawImage(bitmap, 0, 0, canvas.width, canvas.height)
        const url = canvas.toDataURL('image/webp', 0.9)
        if (url.length <= MAX_IMAGE_URL_LENGTH)
          return { url, width: canvas.width, height: canvas.height, optimized: true }
        scale *= 0.75
      }
      throw new Error(`${file.name}: image is too large to embed after conversion`)
    } finally {
      canvas.width = 1
      canvas.height = 1
    }
  } finally {
    bitmap.close()
  }
}
