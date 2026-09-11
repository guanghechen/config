// Run against whiteboard-server.mjs?benchmark using an existing Playwright page.
// The function is self-contained so playwright-cli run-code can execute its source.
export async function benchmarkWhiteboard(page) {
  await page.locator('[data-whiteboard][data-element-count="2000"]').waitFor()
  const results = []
  async function readyScene() {
    await page.locator('[data-whiteboard][data-element-count="2000"]').waitFor()
    await page
      .locator('.wb-card svg[aria-roledescription^="flowchart"]')
      .first()
      .waitFor({ state: 'attached', timeout: 20000 })
    await page
      .locator('.wb-card mjx-container')
      .first()
      .waitFor({ state: 'attached', timeout: 20000 })
    await page.evaluate(async () => {
      await document.fonts.ready
    })
  }
  async function measure(mode, frames = 240) {
    if (mode === 'pan') await page.getByRole('button', { name: 'Hand', exact: true }).click()
    if (mode === 'drag' || mode === 'resize')
      await page.getByRole('button', { name: 'Select', exact: true }).click()
    if (mode === 'resize') {
      await page.mouse.click(320, 220)
      await page.getByRole('heading', { name: '9 selected', exact: true }).waitFor()
    }
    const origin =
      mode === 'resize'
        ? { x: 1500, y: 760 }
        : mode === 'drag'
          ? { x: 320, y: 220 }
          : { x: 1000, y: 700 }
    if (mode !== 'zoom') {
      await page.mouse.move(origin.x, origin.y)
      await page.mouse.down()
    }
    const result = await page.evaluate(
      async ({ mode, frames, origin }) => {
        const stage = document.querySelector('.wb-stage')
        const deltas = []
        let previous
        for (let i = 0; i < frames + 40; i++) {
          const timestamp = await new Promise(resolve => requestAnimationFrame(resolve))
          if (previous !== undefined && i >= 40) deltas.push(timestamp - previous)
          previous = timestamp
          if (mode === 'zoom')
            stage.dispatchEvent(
              new WheelEvent('wheel', {
                bubbles: true,
                cancelable: true,
                ctrlKey: true,
                clientX: 960,
                clientY: 540,
                deltaY: Math.sin(i / 25) * 0.8,
              }),
            )
          else
            stage.dispatchEvent(
              new PointerEvent('pointermove', {
                bubbles: true,
                pointerId: 1,
                pointerType: 'mouse',
                buttons: 1,
                clientX: origin.x + Math.sin(i / 25) * 160,
                clientY: origin.y + Math.sin(i / 35) * 90,
              }),
            )
        }
        deltas.sort((a, b) => a - b)
        return {
          fps: 1000 / (deltas.reduce((a, b) => a + b, 0) / deltas.length),
          p95: deltas[Math.floor(deltas.length * 0.95)],
          max: deltas.at(-1),
          frames: deltas.length,
          mountedCards: document.querySelectorAll('.wb-card').length,
        }
      },
      { mode, frames, origin },
    )
    if (mode !== 'zoom') await page.mouse.up()
    return { mode, ...result }
  }
  for (const mode of ['pan', 'zoom', 'drag', 'resize']) {
    const started = Date.now()
    await page.reload()
    await readyScene()
    const startupMs = Date.now() - started
    results.push({ view: 'reading', startupMs, ...(await measure(mode)) })
  }
  for (const mode of ['pan', 'zoom']) {
    const started = Date.now()
    await page.reload()
    await readyScene()
    await page.getByRole('button', { name: 'Fit all', exact: true }).click()
    const startupMs = Date.now() - started
    results.push({ view: 'overview', startupMs, ...(await measure(mode)) })
  }
  return {
    environment: await page.evaluate(() => ({
      userAgent: navigator.userAgent,
      width: innerWidth,
      height: innerHeight,
      dpr: devicePixelRatio,
    })),
    results,
  }
}
