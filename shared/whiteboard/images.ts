import type { INode, IPoint, IStyle } from './model.ts'

export const MAX_IMAGE_URL_LENGTH = 2_000_000
export const MAX_IMAGE_FILE_BYTES = 20_000_000

export interface IImportedImage {
  readonly url: string
  readonly width: number
  readonly height: number
  readonly optimized: boolean
}

export function rasterMime(bytes: Uint8Array): string | undefined {
  if ([137, 80, 78, 71, 13, 10, 26, 10].every((value, index) => bytes[index] === value))
    return 'image/png'
  if (bytes[0] === 255 && bytes[1] === 216 && bytes[2] === 255) return 'image/jpeg'
  const header = String.fromCharCode(...bytes.subarray(0, 12))
  if (header.startsWith('GIF87a') || header.startsWith('GIF89a')) return 'image/gif'
  if (header.startsWith('RIFF') && header.slice(8, 12) === 'WEBP') return 'image/webp'
  return undefined
}

export function imageNodes(
  images: ReadonlyArray<IImportedImage>,
  center: IPoint,
  style: IStyle,
): INode[] {
  return images.map((image, index) => {
    const scale = Math.min(1, 800 / image.width, 600 / image.height)
    const width = Math.max(1, image.width * scale)
    const height = Math.max(1, image.height * scale)
    return {
      id: crypto.randomUUID(),
      type: 'image',
      url: image.url,
      x: center.x - width / 2 + index * 24,
      y: center.y - height / 2 + index * 24,
      width,
      height,
      style,
    }
  })
}
