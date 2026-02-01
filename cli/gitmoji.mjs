#!/usr/bin/env node

/**
 * Convert gitmoji shortcodes to emoji characters from stdin.
 */

import { Command } from '@guanghechen/stl/commander'
import { Reporter } from '@guanghechen/stl/reporter'
import { convert_gitmoji } from '#src/util/gitmoji'

const reporter = new Reporter({ prefix: 'gitmoji' })

if (process.argv[1] === import.meta.filename) {
  const cmd = new Command('gitmoji', reporter)
    .description('Convert gitmoji shortcodes to emoji characters from stdin.')
    .example('echo ":sparkles: feat: add feature" | gitmoji')
    .example('git log --oneline | gitmoji')
    .action(async () => {
      const chunks = []
      for await (const chunk of process.stdin) {
        chunks.push(chunk)
      }
      const input = Buffer.concat(chunks).toString('utf8')
      const output = convert_gitmoji(input)
      process.stdout.write(output)
    })

  await cmd.run(process.argv.slice(2), /** @type {Record<string, string>} */ (process.env))
}
