import { spawn } from 'node:child_process'
import state from '../state'

export async function findMarkdownFiles(cwd: string): Promise<string[]> {
  return new Promise((resolve, reject) => {
    const fd = spawn(
      'fd',
      [
        '--type',
        'f',
        '--print0',
        ...['html', 'jpg', 'jpeg', 'json', 'md', 'pdf', 'png', 'svg', 'whiteboard']
          .map(ext => ['-e', ext])
          .flat(),
        ...['.git', 'node_modules'].map(dir => ['--exclude', dir]).flat(),
      ],
      {
        cwd,
        shell: false,
      },
    )

    let result = ''
    fd.stdout.on('data', data => {
      result += data.toString()
    })

    fd.stderr.on('data', data => {
      state.reporter.error('Error:', data.toString())
    })

    fd.on('error', reject)

    fd.on('close', code => {
      if (code === 0) {
        resolve(result.split('\0').filter(Boolean).sort()) // Split into an array, filtering out empty lines
      } else {
        reject(new Error(`fd exited with code ${code}`))
      }
    })
  })
}
