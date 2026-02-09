#!/usr/bin/env node

/**
 * Convert gitmoji shortcodes to emoji characters from stdin.
 */

import { Command } from '#stl/commander'
import { Reporter } from '#stl/reporter'
import { convert_gitmoji } from '#util/gitmoji'

const reporter = new Reporter({ prefix: 'gitmoji' })

if (process.argv[1] === import.meta.filename) {
  const cmd = new Command({ name: 'gitmoji', description: 'Convert gitmoji shortcodes to emoji characters from stdin.' })
    .action(async () => {
      const chunks = []
      for await (const chunk of process.stdin) {
        chunks.push(chunk)
      }
      const input = Buffer.concat(chunks).toString('utf8')
      const output = convert_gitmoji(input)
      process.stdout.write(output)
    })

  await cmd.run({ argv: process.argv.slice(2), envs: /** @type {Record<string, string>} */ (process.env), reporter })
}
