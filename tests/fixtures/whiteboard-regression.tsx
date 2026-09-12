import React from 'react'
import { createRoot } from 'react-dom/client'
import { flushSync } from 'react-dom'
import { Whiteboard } from '../../src/view/whiteboard/Whiteboard'
import type { IWhiteboardFile, IWhiteboardFiles } from '../../src/view/whiteboard/contracts'
import { DEFAULT_STYLE, createDocument } from '../../shared/whiteboard/model'
import type { IWhiteboardDocument } from '../../shared/whiteboard/model'

const check = (condition: unknown, message: string): void => {
  if (!condition) throw new Error(message)
}
const wait = async (condition: () => unknown): Promise<void> => {
  const deadline = performance.now() + 5000
  while (!condition()) {
    if (performance.now() > deadline) throw new Error(`Timed out: ${condition}`)
    await new Promise(requestAnimationFrame)
  }
}
const documentWithNode = (title: string, text = false): IWhiteboardDocument => ({
  ...createDocument(),
  title,
  elements: [
    {
      id: title,
      x: 300,
      y: text ? 350 : 150,
      width: 130,
      height: 90,
      style: DEFAULT_STYLE,
      ...(text ? { type: 'text', text: 'Edit me' } : { type: 'shape', shape: 'rectangle' }),
    },
  ],
})
const button = (root: ParentNode, name: string): HTMLButtonElement => {
  const found = [...root.querySelectorAll<HTMLButtonElement>('button')].find(
    element => element.getAttribute('aria-label') === name || element.textContent?.trim() === name,
  )
  if (!found) throw new Error(`Missing button: ${name}`)
  return found
}
const keyboard = (target: HTMLElement, key: string, metaKey = false): void => {
  target.focus()
  for (const type of ['keydown', 'keyup'])
    target.dispatchEvent(new KeyboardEvent(type, { key, metaKey, bubbles: true, cancelable: true }))
}
const guarded = (): boolean => {
  const event = new Event('beforeunload', { cancelable: true })
  window.dispatchEvent(event)
  return event.defaultPrevented
}
const title = (): string | null | undefined => document.querySelector('.wb-board-name')?.textContent
const changeTitle = (value: string): void => {
  const input = document.querySelector<HTMLInputElement>('[aria-label="Whiteboard title"]')!
  Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value')!.set!.call(input, value)
  input.dispatchEvent(new Event('input', { bubbles: true }))
}
const importDocument = (value: IWhiteboardDocument): void => {
  const input = document.querySelector<HTMLInputElement>('[aria-label="Import whiteboard"]')!
  const transfer = new DataTransfer()
  transfer.items.add(
    new File([JSON.stringify(value)], 'import.whiteboard', { type: 'application/json' }),
  )
  input.files = transfer.files
  input.dispatchEvent(new Event('change', { bubbles: true }))
}

export async function runWhiteboardRegression(): Promise<string[]> {
  const root = createRoot(document.getElementById('root')!)
  const passed: string[] = []
  let key = 0
  const mount = async (children: React.ReactNode): Promise<void> => {
    key += 1
    flushSync(() => root.render(<React.StrictMode key={key}>{children}</React.StrictMode>))
    await wait(() => document.querySelector('.wb-stage'))
    await new Promise(requestAnimationFrame)
  }
  try {
    await mount(
      <>
        <button id="outside">Outside</button>
        <div style={{ display: 'flex' }}>
          <Whiteboard
            initialDocument={documentWithNode('one')}
            style={{ width: 600, height: 650 }}
          />
          <Whiteboard
            initialDocument={documentWithNode('two')}
            style={{ width: 600, height: 650 }}
          />
        </div>
      </>,
    )
    const boards = [...document.querySelectorAll<HTMLElement>('.wb')]
    for (const board of boards) keyboard(board.querySelector<HTMLElement>('.wb-stage')!, 'a', true)
    keyboard(boards[1].querySelector<HTMLElement>('.wb-stage')!, 'Delete')
    await wait(() => boards[1].dataset.elementCount === '0')
    check(boards[0].dataset.elementCount === '1', 'Delete affected another board')
    keyboard(document.getElementById('outside')!, 'r')
    await new Promise(requestAnimationFrame)
    check(
      boards.every(board => button(board, 'Rectangle').getAttribute('aria-pressed') !== 'true'),
      'Outside shortcut changed a board',
    )
    passed.push('keyboard ownership')

    keyboard(boards[0].querySelector<HTMLElement>('.wb-stage')!, 'a', true)
    const payload = new DataTransfer()
    payload.setData('text/plain', 'Clipboard belongs to the second board')
    boards[1]
      .querySelector<HTMLElement>('.wb-stage')!
      .dispatchEvent(
        new ClipboardEvent('paste', { bubbles: true, cancelable: true, clipboardData: payload }),
      )
    await wait(() => boards[1].dataset.elementCount === '1')
    check(boards[0].dataset.elementCount === '1', 'Paste affected another board')
    button(boards[0], 'Edit label').click()
    await wait(() => boards[0].querySelector('.wb-label-editor'))
    keyboard(boards[1].querySelector<HTMLElement>('.wb-stage')!, 'a', true)
    keyboard(boards[1].querySelector<HTMLElement>('.wb-stage')!, 'Delete')
    await wait(() => boards[1].dataset.elementCount === '0')
    check(!!boards[0].querySelector('.wb-label-editor'), 'Another board closed the editor')
    passed.push('clipboard and dialog ownership')

    const presented = {
      ...documentWithNode('presented'),
      regions: [
        { id: 'first', name: 'First', x: 200, y: 100, width: 300, height: 200 },
        { id: 'second', name: 'Second', x: 250, y: 150, width: 250, height: 150 },
      ],
      presentation: ['first', 'second'],
    }
    await mount(
      <div style={{ display: 'flex' }}>
        <Whiteboard initialDocument={presented} style={{ width: 600, height: 650 }} />
        <Whiteboard
          initialDocument={documentWithNode('neighbor')}
          style={{ width: 600, height: 650 }}
        />
      </div>,
    )
    const presentationBoards = [...document.querySelectorAll<HTMLElement>('.wb')]
    button(presentationBoards[0], 'Navigate').click()
    await wait(() => presentationBoards[0].querySelector('.wb-area-panel'))
    button(presentationBoards[0], 'Present').click()
    await wait(() => presentationBoards[0].querySelector('.wb-presentation'))
    const neighbor = presentationBoards[1].querySelector('[data-node-id]')!
    const before = neighbor.getBoundingClientRect().x
    keyboard(presentationBoards[1].querySelector<HTMLElement>('.wb-stage')!, 'a', true)
    keyboard(presentationBoards[1].querySelector<HTMLElement>('.wb-stage')!, 'ArrowRight')
    await wait(() => neighbor.getBoundingClientRect().x === before + 1)
    check(
      presentationBoards[0].querySelector('.wb-presentation')!.textContent?.includes('First'),
      'Neighbor keyboard advanced presentation',
    )
    keyboard(presentationBoards[0].querySelector<HTMLElement>('.wb-stage')!, 'ArrowRight')
    await wait(() =>
      presentationBoards[0].querySelector('.wb-presentation')?.textContent?.includes('Second'),
    )
    passed.push('presentation ownership')

    let saved = documentWithNode('source'),
      revision = 'r0'
    const writes: string[] = []
    let releaseSave: () => void = () => {
      throw new Error('No pending save')
    }
    let releaseLoad: () => void = () => {
      throw new Error('No pending reload')
    }
    let delayReload = false
    const files: IWhiteboardFiles = {
      load(filepath, expected) {
        const value: IWhiteboardFile = { filepath, revision, content: JSON.stringify(saved) }
        if (delayReload && expected === undefined)
          return new Promise(resolve => {
            releaseLoad = () => resolve(value)
          })
        return Promise.resolve(expected === revision ? null : value)
      },
      save(_filepath, content, expected) {
        writes.push(expected)
        return new Promise(resolve => {
          releaseSave = () => {
            saved = JSON.parse(content)
            revision = `r${writes.length}`
            resolve(revision)
          }
        })
      },
      async create() {
        return { filepath: '/copy.whiteboard', revision: 'copy' }
      },
    }
    await mount(
      <Whiteboard filepath="/source.whiteboard" host={{ files }} style={{ height: 700 }} />,
    )
    await wait(() => !document.querySelector('.wb-loading'))
    check(!guarded(), 'Clean source was considered unsaved')
    changeTitle('Local changes')
    await wait(() => title() === 'Local changes')
    check(guarded(), 'Missing unload protection without draft storage')
    button(document, 'Save to source file').click()
    await wait(() => writes.length === 1)
    const imported = { ...createDocument(), title: 'Imported while saving' }
    importDocument(imported)
    await wait(() => title() === imported.title)
    releaseSave()
    await wait(() =>
      [...document.querySelectorAll('button')].every(b => b.textContent?.trim() !== 'Saving…'),
    )
    check(
      title() === imported.title && guarded(),
      'Save completion lost or marked newer content saved',
    )
    button(document, 'Save to source file').click()
    await wait(() => writes.length === 2)
    check(writes[1] === 'r1', 'Save revision was discarded by an import')
    releaseSave()
    await wait(() => !guarded())
    passed.push('save/import race and unload protection')

    delayReload = true
    const confirm = window.confirm
    window.confirm = () => true
    try {
      button(document, 'Reload source file').click()
    } finally {
      window.confirm = confirm
    }
    await wait(() => document.querySelector('.wb-loading'))
    importDocument({ ...createDocument(), title: 'Imported while reloading' })
    await wait(() => title() === 'Imported while reloading')
    releaseLoad()
    await wait(() => !document.querySelector('.wb-loading'))
    check(title() === 'Imported while reloading', 'Reload overwrote a newer import')
    passed.push('reload cancellation')

    for (const load of [
      () => {
        throw new Error('Host denied file')
      },
      () => Promise.resolve(null),
    ]) {
      await mount(<Whiteboard filepath="/broken.whiteboard" host={{ files: { ...files, load } }} />)
      await wait(() => document.querySelector('.wb-notice'))
      check(!document.querySelector('.wb-loading'), 'Failed load left the board blocked')
      check(!!document.querySelector('.wb-stage'), 'Host load failure unmounted the editor')
    }
    passed.push('host failure recovery')
    await mount(
      <Whiteboard
        filepath="/notify.whiteboard"
        host={{
          files: {
            ...files,
            load: async filepath => ({
              filepath,
              revision: 'notify',
              content: JSON.stringify(documentWithNode('Notifications')),
            }),
            subscribe() {
              throw new Error('Notifications unavailable')
            },
          },
        }}
      />,
    )
    await wait(() => !document.querySelector('.wb-loading'))
    check(title() === 'Notifications', 'Optional notifications prevented file loading')
    passed.push('notification fallback')

    await mount(
      <Whiteboard
        initialDocument={documentWithNode('text', true)}
        style={{ width: 480, height: 600 }}
      />,
    )
    keyboard(document.querySelector<HTMLElement>('.wb-stage')!, 'a', true)
    await wait(() => document.querySelector('.wb-inspector'))
    button(document, 'Edit content').click()
    await wait(() => document.querySelector('.wb-editor'))
    const board = document.querySelector<HTMLElement>('.wb')!
    const bounds = board.getBoundingClientRect(),
      editor = document.querySelector('.wb-editor')!.getBoundingClientRect()
    check(
      editor.left >= bounds.left &&
        editor.right <= bounds.right &&
        editor.top >= bounds.top &&
        editor.bottom <= bounds.bottom,
      'Embedded content editor was clipped',
    )
    button(document, 'Close editor').click()
    await wait(() => !document.querySelector('.wb-editor'))
    board.querySelector('.wb-stage')!.dispatchEvent(
      new MouseEvent('contextmenu', {
        bubbles: true,
        cancelable: true,
        clientX: bounds.right - 16,
        clientY: bounds.bottom - 16,
      }),
    )
    await wait(() => document.querySelector('.wb-context-menu'))
    const menu = document.querySelector('.wb-context-menu')!.getBoundingClientRect()
    check(
      menu.right <= bounds.right && menu.bottom <= bounds.bottom,
      'Embedded context menu was clipped',
    )
    passed.push('embedded overlays')
    return passed
  } finally {
    flushSync(() => root.unmount())
  }
}
