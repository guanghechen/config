import { spawn } from 'node:child_process'

export async function findMarkdownFiles(cwd: string): Promise<string[]> {
  return new Promise((resolve, reject) => {
    const fd = spawn('fd', ['-e', 'md', '--exclude', 'node_modules', '--exclude', '.git'], {
      cwd,
      shell: true,
    })

    let result = ''
    fd.stdout.on('data', data => {
      result += data.toString()
    })

    fd.stderr.on('data', data => {
      console.error('Error:', data.toString())
    })

    fd.on('close', code => {
      if (code === 0) {
        resolve(result.trim().split('\n').filter(Boolean)) // Split into an array, filtering out empty lines
      } else {
        reject(new Error(`fd exited with code ${code}`))
      }
    })
  })
}
