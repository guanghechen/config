import type { IBounds, IElement, INode } from '@/shared/whiteboard/model'
import { normalizeAngle } from '@/shared/whiteboard/pose'
import type { IWhiteboardFiles } from '../../contracts'
import type { IMarkdownResources, IResourceSnapshot } from '../resources'

const CSS_PROPERTIES =
  `display position top right bottom left box-sizing width height min-width min-height max-width max-height
margin-top margin-right margin-bottom margin-left padding-top padding-right padding-bottom padding-left
border-top border-right border-bottom border-left border-radius border-collapse border-spacing table-layout
color background-color background-image background-size background-position background-repeat background-clip
font-family font-size font-weight font-style font-variant font-stretch font-feature-settings font-variation-settings font-kerning font-optical-sizing line-height letter-spacing word-spacing
text-align text-indent text-transform text-decoration text-shadow white-space word-break overflow-wrap tab-size
vertical-align direction writing-mode overflow overflow-x overflow-y opacity visibility transform transform-origin
box-shadow clip-path float clear z-index isolation object-fit object-position aspect-ratio
flex-direction flex-wrap flex-grow flex-shrink flex-basis justify-content align-items align-content align-self order gap
 grid-template-columns grid-template-rows grid-column grid-row list-style-type list-style-position list-style-image
fill fill-opacity fill-rule stroke stroke-width stroke-opacity stroke-dasharray stroke-dashoffset stroke-linecap stroke-linejoin
marker-start marker-mid marker-end text-anchor dominant-baseline paint-order`.split(/\s+/)

export async function frozenMarkdown(
  elements: ReadonlyArray<IElement>,
  signal: AbortSignal,
  source?: IWhiteboardFiles,
): Promise<IMarkdownResources> {
  const files = [
    ...new Set(
      elements.flatMap(element =>
        element.type === 'markdown' && element.source.kind === 'file'
          ? [element.source.filepath]
          : [],
      ),
    ),
  ]
  const snapshots = new Map<string, IResourceSnapshot>()
  let next = 0
  await Promise.all(
    Array.from({ length: Math.min(4, files.length) }, async () => {
      while (next < files.length) {
        const filepath = files[next++]
        const data = await source?.load(filepath, undefined, signal)
        if (!data) throw new Error(`Unable to render Markdown file: ${filepath}`)
        snapshots.set(filepath, { data })
      }
    }),
  )
  return {
    get: filepath => snapshots.get(filepath) ?? { error: `Missing export resource: ${filepath}` },
    subscribe: () => () => {},
  }
}

export async function blobDataUrl(blob: Blob): Promise<string> {
  const bytes = new Uint8Array(await blob.arrayBuffer()),
    parts: string[] = []
  for (let index = 0; index < bytes.length; index += 8192)
    parts.push(String.fromCharCode(...bytes.subarray(index, index + 8192)))
  return `data:${blob.type || 'application/octet-stream'};base64,${btoa(parts.join(''))}`
}

export class ExportAssets {
  private cache = new Map<string, Promise<string>>()
  private styles = new Map<string, string>()
  private bytes = 0
  public fonts = new Set<string>()
  private signal: AbortSignal
  constructor(signal: AbortSignal) {
    this.signal = signal
  }

  public styleClass = (css: string): string => {
    let name = this.styles.get(css)
    if (!name) {
      name = `wb-export-${this.styles.size}`
      this.styles.set(css, name)
    }
    return name
  }

  public styleSheet = (): string =>
    [...this.styles].map(([css, name]) => `.${name}{${css}}`).join('\n')

  public embed = (url: string, base = document.baseURI): Promise<string> => {
    if (url.startsWith('data:') || url.startsWith('#')) return Promise.resolve(url)
    const resolved = new URL(url, base)
    if (
      resolved.hash &&
      resolved.origin === location.origin &&
      resolved.pathname === location.pathname
    )
      return Promise.resolve(resolved.hash)
    const key = resolved.href
    let pending = this.cache.get(key)
    if (!pending) {
      pending = (async () => {
        const response = await fetch(key, { signal: this.signal })
        if (!response.ok) throw new Error(`Unable to embed resource (${response.status}): ${key}`)
        const blob = await response.blob()
        this.bytes += blob.size
        if (blob.size > 30_000_000 || this.bytes > 60_000_000)
          throw new Error('Export resources exceed 60 MB; export a smaller selection')
        return blobDataUrl(blob)
      })()
      this.cache.set(key, pending)
    }
    return pending
  }

  public css = async (value: string, base?: string): Promise<string> => {
    let result = '',
      offset = 0
    for (const match of value.matchAll(/url\((?:"([^"]*)"|'([^']*)'|([^)]*))\)/g)) {
      result +=
        value.slice(offset, match.index) +
        `url("${await this.embed(match[1] ?? match[2] ?? match[3].trim(), base)}")`
      offset = match.index + match[0].length
    }
    return result + value.slice(offset)
  }

  public fontFaces = async (): Promise<string> => {
    const output: string[] = []
    const visit = async (rules: CSSRuleList, base: string): Promise<void> => {
      for (const rule of rules) {
        if (rule instanceof CSSFontFaceRule) {
          const family = rule.style.fontFamily.replace(/["']/g, '').toLowerCase()
          if (
            ![...this.fonts].some(font =>
              font
                .toLowerCase()
                .split(',')
                .some(part => part.trim().replace(/["']/g, '') === family),
            )
          )
            continue
          const embedded = await this.css(rule.style.cssText, base)
          // SVG-as-image may paint before a cold data-URL font has decoded, even after image.decode().
          // Warm that exact embedded source without adding or replacing fonts in the live document.
          await new FontFace(
            'Whiteboard export',
            await this.css(rule.style.getPropertyValue('src'), base),
          ).load()
          output.push(`@font-face{${embedded}}`)
        } else if (rule instanceof CSSImportRule && rule.styleSheet) {
          await visit(rule.styleSheet.cssRules, rule.href)
        } else if ('cssRules' in rule) {
          await visit((rule as CSSGroupingRule).cssRules, base)
        }
      }
    }
    for (const sheet of document.styleSheets) {
      // Reading a cross-origin stylesheet can fail even when its fonts are already loaded.
      // Fail explicitly: silently dropping a web font changes text or MathJax glyphs in the artifact.
      try {
        await visit(sheet.cssRules, sheet.href ?? document.baseURI)
      } catch (error) {
        throw new Error(
          `Unable to embed export fonts from ${sheet.href ?? 'inline stylesheet'}: ${String(error)}`,
          { cause: error },
        )
      }
    }
    return output.join('\n')
  }
}

async function inlineStyle(
  source: Element,
  target: Element,
  assets: ExportAssets,
  pseudo?: string,
): Promise<void> {
  const computed = getComputedStyle(source, pseudo)
  assets.fonts.add(computed.fontFamily)
  const declarations: string[] = []
  for (const property of CSS_PROPERTIES) {
    const value = computed.getPropertyValue(property)
    if (value)
      declarations.push(`${property}:${value.includes('url(') ? await assets.css(value) : value}`)
  }
  target.removeAttribute('style')
  target.setAttribute('class', assets.styleClass(declarations.join(';')))
}

async function pseudoContent(
  source: Element,
  pseudo: '::before' | '::after',
  assets: ExportAssets,
): Promise<HTMLElement | null> {
  const content = getComputedStyle(source, pseudo).content
  if (!content || content === 'none' || content === 'normal' || content === '""') return null
  if (!/^(["']).*\1$/s.test(content))
    throw new Error(`Unsupported generated content in ${source.tagName}: ${content}`)
  const span = document.createElement('span')
  span.textContent = content
    .slice(1, -1)
    .replace(/\\([\da-f]{1,6})\s?|\\(.)/gi, (_match, hex, character) =>
      hex ? String.fromCodePoint(parseInt(hex, 16)) : character,
    )
  await inlineStyle(source, span, assets, pseudo)
  return span
}

export async function cloneArtwork(source: Element, assets: ExportAssets): Promise<Element> {
  if (source.matches('iframe,object,embed,video,audio'))
    throw new Error(`Export does not support embedded ${source.tagName.toLowerCase()}`)
  let clone = source.cloneNode(false) as Element
  if (source instanceof HTMLCanvasElement) {
    const image = document.createElement('img')
    image.src = source.toDataURL('image/png')
    clone = image
  }
  for (const attribute of [...clone.attributes]) {
    if (attribute.name.startsWith('on') || ['srcset', 'sizes', 'loading'].includes(attribute.name))
      clone.removeAttribute(attribute.name)
  }
  await inlineStyle(source, clone, assets)
  if (source instanceof HTMLImageElement)
    clone.setAttribute('src', await assets.embed(source.currentSrc || source.src))
  if (source instanceof SVGImageElement) {
    const url = source.href.baseVal
    clone.setAttribute('href', await assets.embed(url))
    clone.removeAttributeNS('http://www.w3.org/1999/xlink', 'href')
  }
  if (source instanceof SVGUseElement) {
    const href = await assets.embed(source.href.baseVal)
    if (!href.startsWith('#')) throw new Error('External SVG symbol references cannot be exported')
    clone.setAttribute('href', href)
    clone.removeAttributeNS('http://www.w3.org/1999/xlink', 'href')
  }
  if (
    source instanceof HTMLAnchorElement &&
    !/^(https?:|#)/i.test(source.getAttribute('href') ?? '')
  )
    clone.removeAttribute('href')
  if (!(source instanceof HTMLCanvasElement)) {
    const before =
      source instanceof HTMLElement ? await pseudoContent(source, '::before', assets) : null
    if (before) clone.append(before)
    for (const child of source.childNodes) {
      if (child instanceof Element) {
        if (!child.matches('script,style,mjx-assistive-mml'))
          clone.append(await cloneArtwork(child, assets))
      } else clone.append(child.cloneNode())
    }
    const after =
      source instanceof HTMLElement ? await pseudoContent(source, '::after', assets) : null
    if (after) clone.append(after)
  }
  return clone
}

export async function waitForArtwork(host: HTMLElement, signal: AbortSignal): Promise<void> {
  let readySince = 0
  const deadline = Date.now() + 20_000
  for (;;) {
    signal.throwIfAborted()
    const error = host.querySelector('[role="alert"],mjx-merror,[data-render-state="error"]')
    if (error)
      throw new Error(
        `Unable to export content: ${error.textContent?.trim().slice(0, 500) || 'Rendering failed'}`,
      )
    const images = [...host.querySelectorAll('img')]
    for (const image of images) image.loading = 'eager'
    const failed = images.find(image => image.complete && !image.naturalWidth)
    if (failed) throw new Error(`Unable to load export image: ${failed.currentSrc || failed.src}`)
    const pending =
      !host.childElementCount ||
      host.querySelector('.wb-placeholder,[data-export-pending],[data-render-state="pending"]') ||
      [...host.querySelectorAll('.yozora-math,.yozora-inline-math')].some(
        node => !node.querySelector('mjx-container'),
      ) ||
      images.some(image => !image.complete) ||
      document.fonts.status !== 'loaded'
    if (pending) readySince = 0
    else readySince ||= Date.now()
    if (readySince && Date.now() - readySince >= 150) return
    if (Date.now() >= deadline)
      throw new Error(
        'Content is still loading after 20 seconds. Retry after its images, formulas and diagrams load.',
      )
    await new Promise<void>(resolve => setTimeout(resolve, 50))
  }
}

export async function serializeDrawing(
  source: Element,
  element: IElement,
  assets: ExportAssets,
): Promise<string> {
  const clone = await cloneArtwork(source, assets)
  if (element.type !== 'markdown' && element.type !== 'image') {
    const svg = clone as SVGSVGElement
    svg.setAttribute('x', (source as SVGSVGElement).style.left)
    svg.setAttribute('y', (source as SVGSVGElement).style.top)
    svg.style.position = 'static'
    svg.style.left = svg.style.top = 'auto'
    return new XMLSerializer().serializeToString(svg)
  }
  const node: INode = element
  const padding = node.style.strokeWidth + node.style.roughness * 4 + 8
  const article = clone as HTMLElement
  article.style.transform = 'none'
  article.style.left = article.style.top = `${padding}px`
  const outer = document.createElement('div')
  outer.setAttribute('xmlns', 'http://www.w3.org/1999/xhtml')
  outer.style.cssText = `position:relative;width:${node.width + padding * 2}px;height:${node.height + padding * 2}px;overflow:hidden;`
  outer.append(article)
  return `<g transform="translate(${node.x + node.width / 2} ${node.y + node.height / 2}) rotate(${normalizeAngle(node.rotation ?? 0)}) scale(${node.flipX ? -1 : 1} ${node.flipY ? -1 : 1}) translate(${-node.width / 2} ${-node.height / 2})"><foreignObject x="${-padding}" y="${-padding}" width="${node.width + padding * 2}" height="${node.height + padding * 2}">${new XMLSerializer().serializeToString(outer)}</foreignObject></g>`
}

export function svgDocument(
  parts: ReadonlyArray<string>,
  bounds: IBounds,
  fonts: string,
  background?: string,
): string {
  return `<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="${bounds.width}" height="${bounds.height}" viewBox="${bounds.x} ${bounds.y} ${bounds.width} ${bounds.height}"><style>${fonts.replaceAll('&', '&amp;').replaceAll('<', '&lt;')}</style>${background ? `<rect x="${bounds.x}" y="${bounds.y}" width="${bounds.width}" height="${bounds.height}" fill="${background}"/>` : ''}${parts.join('')}</svg>`
}

export async function rasterize(
  svg: string,
  size: { width: number; height: number },
  signal: AbortSignal,
): Promise<Blob> {
  const image = new Image()
  image.src = await blobDataUrl(new Blob([svg], { type: 'image/svg+xml;charset=utf-8' }))
  await image.decode()
  signal.throwIfAborted()
  const canvas = document.createElement('canvas')
  canvas.width = size.width
  canvas.height = size.height
  try {
    canvas.getContext('2d')!.drawImage(image, 0, 0, size.width, size.height)
    return await new Promise<Blob>((resolve, reject) =>
      canvas.toBlob(blob => {
        if (signal.aborted) reject(signal.reason)
        else if (blob) resolve(blob)
        else reject(new Error('Unable to encode the PNG'))
      }, 'image/png'),
    )
  } finally {
    canvas.width = canvas.height = 0
    image.removeAttribute('src')
  }
}
