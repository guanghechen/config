#!/usr/bin/env node
import { readFile, realpath } from 'node:fs/promises'
import path from 'node:path'
import { parseArgs } from 'node:util'
import { parseDocument } from '../shared/whiteboard/document.ts'
import { applyCommands } from '../shared/whiteboard/commands.ts'
import { createDocument } from '../shared/whiteboard/model.ts'
import { isWhiteboardFilename } from '../shared/whiteboard/files.ts'
import {
  createVersionedText,
  readVersionedText,
  saveVersionedText,
  textRevision,
} from '../server/util/versioned-text.ts'

try {
  const { positionals, values } = parseArgs({
    allowPositionals: true,
    options: {
      commands: { type: 'string' },
      revision: { type: 'string' },
      'dry-run': { type: 'boolean' },
      title: { type: 'string' },
      help: { type: 'boolean' },
    },
  })
  const [action, filename] = positionals
  if (values.help || !action) {
    console.log(
      JSON.stringify(
        {
          usage: 'node scripts/whiteboard.mjs <inspect|validate|create|apply> file.whiteboard',
          commands:
            'apply requires --commands batch.json and --revision SHA256; --dry-run validates without writing',
          runtime: 'Node 24+',
          schema: 'spec/whiteboard/document.schema.json',
          batchSchema: 'spec/whiteboard/commands.schema.json',
        },
        null,
        2,
      ),
    )
  } else {
    if (positionals.length !== 2 || !filename?.toLowerCase().endsWith('.whiteboard'))
      throw new Error('Provide exactly one .whiteboard filepath')
    if (action !== 'apply' && (values.commands || values.revision || values['dry-run']))
      throw new Error('--commands, --revision and --dry-run are only valid with apply')
    if (action !== 'create' && values.title !== undefined)
      throw new Error('--title is only valid with create')
    const requested = path.resolve(filename)
    const filepath =
      action === 'create'
        ? path.join(await realpath(path.dirname(requested)), path.basename(requested))
        : await realpath(requested)
    if (!filepath.toLowerCase().endsWith('.whiteboard'))
      throw new Error('The canonical file must end in .whiteboard')
    if (action === 'create') {
      if (!isWhiteboardFilename(path.basename(filepath)))
        throw new Error('Invalid whiteboard filename')
      const document = { ...createDocument(), title: values.title ?? 'Untitled whiteboard' }
      const snapshot = await createVersionedText(filepath, JSON.stringify(document, null, 2) + '\n')
      console.log(
        JSON.stringify({
          ok: true,
          filepath,
          revision: snapshot.revision,
          documentId: document.id,
          elements: 0,
        }),
      )
    } else {
      const snapshot = await readVersionedText(filepath)
      const document = parseDocument(snapshot.content)
      if (action === 'validate')
        console.log(
          JSON.stringify({
            ok: true,
            filepath,
            revision: snapshot.revision,
            documentId: document.id,
            elements: document.elements.length,
          }),
        )
      else if (action === 'inspect')
        console.log(
          JSON.stringify({ ok: true, filepath, revision: snapshot.revision, document }, null, 2),
        )
      else if (action === 'apply') {
        if (!values.commands) throw new Error('apply requires --commands batch.json')
        if (!values['dry-run'] && !values.revision)
          throw new Error('apply requires --revision from inspect/validate')
        if (values.revision && values.revision !== snapshot.revision)
          throw new Error('Revision conflict; inspect the current document and retry')
        const commands = JSON.parse(await readFile(values.commands, 'utf8'))
        const next = applyCommands(document, commands)
        const content = next === document ? snapshot.content : JSON.stringify(next, null, 2) + '\n'
        if (!values['dry-run'] && next !== document)
          await saveVersionedText(filepath, content, snapshot.revision)
        console.log(
          JSON.stringify(
            {
              ok: true,
              dryRun: !!values['dry-run'],
              changed: next !== document,
              filepath,
              documentId: next.id,
              previousRevision: snapshot.revision,
              revision: textRevision(content),
              elements: next.elements.length,
              ...(values['dry-run'] ? { document: next } : {}),
            },
            null,
            2,
          ),
        )
      } else throw new Error(`Unknown action: ${action}`)
    }
  }
} catch (error) {
  console.error(
    JSON.stringify({ ok: false, error: error instanceof Error ? error.message : String(error) }),
  )
  process.exitCode = 1
}
