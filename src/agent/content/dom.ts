import type { AgentCapability, IAgentElementDescriptor, IAgentSnapshot } from '@/agent/contract'
import { isSafeDomSelector } from './selector'

const DEFAULT_SNAPSHOT_LIMIT = 300
const DOM_SCAN_BATCH_SIZE = 250
const MAX_DOM_SCAN_ELEMENTS = 20_000
const MAX_QUERY_RESULTS = 100
const MAX_TEXT_LENGTH = 20_000
const MAX_NAME_LENGTH = 240
const SAFE_ATTRIBUTE_NAMES = new Set(['alt', 'class', 'id', 'name', 'role', 'title', 'type'])
const EXCLUDED_TEXT_ELEMENT_SELECTOR = 'script,style,template,noscript'
const SENSITIVE_ELEMENT_SELECTOR = 'input,textarea,select,option,[contenteditable]'

interface ISnapshotState {
  readonly id: string
  readonly elements: Map<string, Element>
}

export class DomCapabilityRuntime {
  private snapshot: ISnapshotState | null = null

  public async execute(
    capability: AgentCapability,
    payload: unknown,
    signal: AbortSignal,
  ): Promise<unknown> {
    switch (capability) {
      case 'dom.snapshot':
        return this.createSnapshot(readLimit(payload, DEFAULT_SNAPSHOT_LIMIT), signal)
      case 'dom.query':
        return this.query(payload, signal)
      case 'dom.getText':
        return this.getText(payload, signal)
      case 'dom.getAttributes':
        return this.getAttributes(payload)
      case 'dom.getBounds':
        return this.getBounds(payload)
      default:
        throw createCapabilityError(
          'CAPABILITY_UNAVAILABLE',
          `Unsupported DOM capability: ${capability}`,
        )
    }
  }

  private async createSnapshot(
    limit: number,
    signal: AbortSignal,
    elements?: ReadonlyArray<Element>,
  ): Promise<IAgentSnapshot> {
    const candidates =
      elements ??
      (await collectElements(
        document.body ?? document.documentElement,
        limit + 1,
        signal,
        isSemanticElement,
      ))
    const selected = candidates.slice(0, limit)
    const snapshotId = crypto.randomUUID()
    const snapshotElements = new Map<string, Element>()
    const descriptors: IAgentElementDescriptor[] = []

    for (const [index, element] of selected.entries()) {
      const ref = `e${index + 1}`
      snapshotElements.set(ref, element)
      descriptors.push(await describeElement(element, ref, signal))
    }

    this.snapshot = { id: snapshotId, elements: snapshotElements }
    return {
      snapshotId,
      elements: descriptors,
      truncated: candidates.length > selected.length,
    }
  }

  private async query(payload: unknown, signal: AbortSignal): Promise<IAgentSnapshot> {
    const request = readRecord(payload)
    const selector = readString(request.selector, 'selector')
    if (!isSafeDomSelector(selector)) {
      throw createCapabilityError('INVALID_REQUEST', 'Selector is unsupported or too long.')
    }

    const limit = Math.min(readLimit(payload, MAX_QUERY_RESULTS), MAX_QUERY_RESULTS)
    let matchesElement: (element: Element) => boolean
    try {
      document.documentElement.matches(selector)
      matchesElement = element => element.matches(selector)
    } catch {
      throw createCapabilityError('INVALID_REQUEST', 'Selector is invalid.')
    }

    const elements = await collectElements(
      document.body ?? document.documentElement,
      limit + 1,
      signal,
      matchesElement,
    )
    return this.createSnapshot(limit, signal, elements)
  }

  private async getText(payload: unknown, signal: AbortSignal): Promise<{ readonly text: string }> {
    const element = this.resolveElement(payload)
    assertNotSensitive(element)
    return { text: await readSafeText(element, MAX_TEXT_LENGTH, signal) }
  }

  private getAttributes(payload: unknown): { readonly attributes: Record<string, string> } {
    const element = this.resolveElement(payload)
    assertNotSensitive(element)
    const attributes: Record<string, string> = {}

    for (const attribute of element.attributes) {
      if (
        !SAFE_ATTRIBUTE_NAMES.has(attribute.name) &&
        !attribute.name.startsWith('aria-') &&
        attribute.name !== 'href' &&
        attribute.name !== 'src'
      ) {
        continue
      }

      const value =
        attribute.name === 'href' || attribute.name === 'src'
          ? sanitizeUrl(attribute.value)
          : attribute.value
      attributes[attribute.name] = value.slice(0, MAX_NAME_LENGTH)
    }

    return { attributes }
  }

  private getBounds(payload: unknown): {
    readonly x: number
    readonly y: number
    readonly width: number
    readonly height: number
  } {
    const element = this.resolveElement(payload)
    const bounds = element.getBoundingClientRect()
    return {
      x: bounds.x,
      y: bounds.y,
      width: bounds.width,
      height: bounds.height,
    }
  }

  private resolveElement(payload: unknown): Element {
    const request = readRecord(payload)
    const snapshotId = readString(request.snapshotId, 'snapshotId')
    const ref = readString(request.ref, 'ref')
    if (!this.snapshot || this.snapshot.id !== snapshotId) {
      throw createCapabilityError('STALE_SNAPSHOT', 'Snapshot is no longer active.')
    }

    const element = this.snapshot.elements.get(ref)
    if (!element || !element.isConnected) {
      throw createCapabilityError('STALE_ELEMENT', 'Element is detached or unknown.')
    }
    return element
  }
}

async function collectElements(
  root: Element,
  limit: number,
  signal: AbortSignal,
  matchesElement: (element: Element) => boolean,
): Promise<Element[]> {
  const elements: Element[] = []
  const walker = document.createTreeWalker(root, NodeFilter.SHOW_ELEMENT)
  let node = walker.currentNode as Element
  let scannedElements = 0

  while (node) {
    assertWithinScanBudget(++scannedElements)
    assertNotAborted(signal)

    if (matchesElement(node) && isVisible(node)) {
      elements.push(node)
      if (elements.length >= limit) break
    }

    if (scannedElements % DOM_SCAN_BATCH_SIZE === 0) await yieldToBrowser(signal)
    const next = walker.nextNode()
    if (!next) break
    node = next as Element
  }

  return elements
}

function isSemanticElement(element: Element): boolean {
  if (element.matches('a,button,input,select,textarea,summary,[role],[contenteditable]'))
    return true
  return /^H[1-6]$/.test(element.tagName) || element.matches('main,nav,form,table,article,section')
}

function isVisible(element: Element): boolean {
  const style = getComputedStyle(element)
  const bounds = element.getBoundingClientRect()
  return (
    style.display !== 'none' &&
    style.visibility !== 'hidden' &&
    style.visibility !== 'collapse' &&
    style.opacity !== '0' &&
    !element.closest('[aria-hidden="true"]') &&
    bounds.width > 0 &&
    bounds.height > 0
  )
}

async function describeElement(
  element: Element,
  ref: string,
  signal: AbortSignal,
): Promise<IAgentElementDescriptor> {
  return {
    ref,
    role: resolveRole(element),
    name: await resolveName(element, signal),
    tag: element.tagName.toLowerCase(),
  }
}

function resolveRole(element: Element): string {
  const explicitRole = element.getAttribute('role')
  if (explicitRole) return explicitRole

  const roles: Record<string, string> = {
    A: 'link',
    BUTTON: 'button',
    FORM: 'form',
    INPUT: resolveInputRole(element),
    MAIN: 'main',
    NAV: 'navigation',
    SELECT: 'combobox',
    TABLE: 'table',
    TEXTAREA: 'textbox',
  }
  return roles[element.tagName] ?? (/^H[1-6]$/.test(element.tagName) ? 'heading' : 'generic')
}

function resolveInputRole(element: Element): string {
  const type = element.getAttribute('type')?.toLowerCase()
  if (type === 'checkbox') return 'checkbox'
  if (type === 'radio') return 'radio'
  if (type === 'button' || type === 'submit' || type === 'reset') return 'button'
  return 'textbox'
}

async function resolveName(element: Element, signal: AbortSignal): Promise<string> {
  if (isSensitiveElement(element)) return '[redacted]'
  const name =
    element.getAttribute('aria-label') ||
    element.getAttribute('alt') ||
    element.getAttribute('title') ||
    (await readSafeText(element, MAX_NAME_LENGTH, signal))
  return normalizeText(name).slice(0, MAX_NAME_LENGTH)
}

async function readSafeText(element: Element, limit: number, signal: AbortSignal): Promise<string> {
  if (isSensitiveElement(element)) return '[redacted]'

  const parts: string[] = []
  const stack: Node[] = [element]
  const textBudget = limit * 2
  let collectedLength = 0
  let scannedNodes = 0

  while (stack.length > 0 && collectedLength < textBudget) {
    const node = stack.pop()
    if (!node) break

    assertWithinScanBudget(++scannedNodes)
    assertNotAborted(signal)

    if (node.nodeType === Node.TEXT_NODE) {
      const text = node.textContent ?? ''
      const remaining = textBudget - collectedLength
      if (text && remaining > 0) {
        const chunk = text.slice(0, remaining)
        parts.push(chunk)
        collectedLength += chunk.length
      }
    } else if (node instanceof Element) {
      if (node !== element && isSensitiveElement(node)) {
        parts.push('[redacted]')
        collectedLength += 10
        continue
      }
      if (
        node !== element &&
        (node.matches(EXCLUDED_TEXT_ELEMENT_SELECTOR) || isTextSubtreeHidden(node))
      ) {
        continue
      }

      for (let index = node.childNodes.length - 1; index >= 0; index -= 1) {
        const child = node.childNodes[index]
        if (child) stack.push(child)
      }
    }

    if (scannedNodes % DOM_SCAN_BATCH_SIZE === 0) await yieldToBrowser(signal)
  }

  return normalizeText(parts.join(' ')).slice(0, limit)
}

function isSensitiveElement(element: Element): boolean {
  if (element.matches(SENSITIVE_ELEMENT_SELECTOR)) return true
  return Boolean(element.closest('[contenteditable],select'))
}

function assertNotSensitive(element: Element): void {
  if (isSensitiveElement(element)) {
    throw createCapabilityError('SENSITIVE_ELEMENT', 'Sensitive form content is not readable.')
  }
}

function sanitizeUrl(value: string): string {
  try {
    const url = new URL(value, window.location.href)
    if (url.protocol !== 'http:' && url.protocol !== 'https:') return ''
    return `${url.origin}${url.pathname}`
  } catch {
    return ''
  }
}

function isTextSubtreeHidden(element: Element): boolean {
  if (element.hasAttribute('hidden') || element.getAttribute('aria-hidden') === 'true') return true
  const style = getComputedStyle(element)
  return (
    style.display === 'none' ||
    style.visibility === 'hidden' ||
    style.visibility === 'collapse' ||
    style.opacity === '0'
  )
}

function assertWithinScanBudget(scannedNodes: number): void {
  if (scannedNodes <= MAX_DOM_SCAN_ELEMENTS) return
  throw createCapabilityError('PAYLOAD_TOO_LARGE', 'DOM scan exceeded the safety limit.')
}

function assertNotAborted(signal: AbortSignal): void {
  if (signal.aborted) throw createCapabilityError('TIMEOUT', 'Page request timed out.')
}

async function yieldToBrowser(signal: AbortSignal): Promise<void> {
  await new Promise<void>(resolve => window.setTimeout(resolve, 0))
  assertNotAborted(signal)
}

function normalizeText(value: string): string {
  return value.replace(/\s+/g, ' ').trim()
}

function readLimit(payload: unknown, fallback: number): number {
  const request = readRecord(payload, false)
  const value = request.limit
  if (typeof value !== 'number' || !Number.isInteger(value) || value <= 0) return fallback
  return Math.min(value, fallback)
}

function readRecord(value: unknown, required = true): Record<string, unknown> {
  if (typeof value === 'object' && value !== null && !Array.isArray(value)) {
    return value as Record<string, unknown>
  }
  if (!required) return {}
  throw createCapabilityError('INVALID_REQUEST', 'Payload must be an object.')
}

function readString(value: unknown, field: string): string {
  if (typeof value === 'string' && value) return value
  throw createCapabilityError('INVALID_REQUEST', `${field} must be a non-empty string.`)
}

function createCapabilityError(code: string, message: string): Error {
  return Object.assign(new Error(message), { code })
}
