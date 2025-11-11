interface ISwordPalette {
  readonly text: string
  readonly background: string
  readonly windShadow: string
  readonly glow: string
  readonly hoverGlow: string
  readonly aura: string
  readonly contentShadow: string
  readonly blade: string
  readonly bladeShadow: string
  readonly guard: string
  readonly guardShadow: string
  readonly tip: string
  readonly tipShadow: string
}

const swordPalettes: ReadonlyArray<ISwordPalette> = [
  {
    text: '#0f766e',
    background:
      'linear-gradient(120deg, rgba(16, 185, 129, 0.18) 0%, rgba(34, 197, 94, 0.12) 45%, rgba(45, 212, 191, 0.18) 100%)',
    windShadow:
      '0 8px 22px rgba(45, 212, 191, 0.22), 0 2px 8px rgba(20, 184, 166, 0.18)',
    glow: 'rgba(45, 212, 191, 0.2)',
    hoverGlow: 'rgba(56, 189, 248, 0.35)',
    aura:
      'radial-gradient(ellipse at center, rgba(45, 212, 191, 0.45) 0%, rgba(56, 189, 248, 0.32) 45%, rgba(56, 189, 248, 0) 80%)',
    contentShadow: 'rgba(226, 255, 244, 0.65)',
    blade: 'linear-gradient(90deg, #ecfccb 0%, #a7f3d0 25%, #5eead4 55%, #22d3ee 75%, #0f766e 100%)',
    bladeShadow:
      '0 0 8px rgba(16, 185, 129, 0.35), 0 0 14px rgba(20, 184, 166, 0.25)',
    guard:
      'linear-gradient(135deg, rgba(15, 118, 110, 0.95) 0%, rgba(34, 197, 94, 0.88) 50%, rgba(56, 189, 248, 0.85) 100%)',
    guardShadow:
      '0 0 10px rgba(45, 212, 191, 0.45), 0 0 6px rgba(34, 197, 94, 0.4)',
    tip:
      'linear-gradient(115deg, rgba(186, 230, 253, 0.9) 0%, rgba(56, 189, 248, 0.85) 60%, rgba(14, 165, 233, 0.88) 100%)',
    tipShadow:
      '0 0 10px rgba(56, 189, 248, 0.45), 0 0 6px rgba(34, 197, 94, 0.35)',
  },
  {
    text: '#075985',
    background:
      'linear-gradient(120deg, rgba(14, 165, 233, 0.18) 0%, rgba(37, 99, 235, 0.12) 50%, rgba(59, 130, 246, 0.18) 100%)',
    windShadow:
      '0 8px 22px rgba(59, 130, 246, 0.24), 0 2px 8px rgba(14, 165, 233, 0.2)',
    glow: 'rgba(59, 130, 246, 0.22)',
    hoverGlow: 'rgba(14, 165, 233, 0.4)',
    aura:
      'radial-gradient(ellipse at center, rgba(129, 212, 250, 0.5) 0%, rgba(37, 99, 235, 0.3) 45%, rgba(59, 130, 246, 0) 80%)',
    contentShadow: 'rgba(219, 234, 254, 0.75)',
    blade: 'linear-gradient(90deg, #dbeafe 0%, #bfdbfe 25%, #93c5fd 55%, #60a5fa 75%, #1d4ed8 100%)',
    bladeShadow:
      '0 0 8px rgba(59, 130, 246, 0.4), 0 0 14px rgba(14, 165, 233, 0.28)',
    guard:
      'linear-gradient(135deg, rgba(15, 118, 110, 0.85) 0%, rgba(37, 99, 235, 0.88) 55%, rgba(59, 130, 246, 0.9) 100%)',
    guardShadow:
      '0 0 10px rgba(59, 130, 246, 0.55), 0 0 6px rgba(37, 99, 235, 0.45)',
    tip:
      'linear-gradient(115deg, rgba(191, 219, 254, 0.95) 0%, rgba(96, 165, 250, 0.9) 60%, rgba(29, 78, 216, 0.9) 100%)',
    tipShadow:
      '0 0 10px rgba(96, 165, 250, 0.55), 0 0 6px rgba(37, 99, 235, 0.4)',
  },
  {
    text: '#92400e',
    background:
      'linear-gradient(120deg, rgba(249, 115, 22, 0.18) 0%, rgba(217, 119, 6, 0.12) 45%, rgba(245, 158, 11, 0.18) 100%)',
    windShadow:
      '0 8px 22px rgba(245, 158, 11, 0.26), 0 2px 8px rgba(249, 115, 22, 0.2)',
    glow: 'rgba(245, 158, 11, 0.3)',
    hoverGlow: 'rgba(249, 115, 22, 0.45)',
    aura:
      'radial-gradient(ellipse at center, rgba(250, 204, 21, 0.5) 0%, rgba(251, 191, 36, 0.35) 45%, rgba(251, 191, 36, 0) 80%)',
    contentShadow: 'rgba(254, 243, 199, 0.75)',
    blade: 'linear-gradient(90deg, #fef3c7 0%, #fde68a 25%, #fcd34d 55%, #f59e0b 75%, #ea580c 100%)',
    bladeShadow:
      '0 0 8px rgba(249, 115, 22, 0.35), 0 0 14px rgba(234, 179, 8, 0.3)',
    guard:
      'linear-gradient(135deg, rgba(249, 115, 22, 0.95) 0%, rgba(245, 158, 11, 0.9) 55%, rgba(234, 88, 12, 0.9) 100%)',
    guardShadow:
      '0 0 10px rgba(251, 191, 36, 0.5), 0 0 6px rgba(249, 115, 22, 0.45)',
    tip:
      'linear-gradient(115deg, rgba(254, 228, 138, 0.95) 0%, rgba(252, 211, 77, 0.9) 60%, rgba(251, 146, 60, 0.9) 100%)',
    tipShadow:
      '0 0 10px rgba(251, 191, 36, 0.55), 0 0 6px rgba(249, 115, 22, 0.45)',
  },
  {
    text: '#6b21a8',
    background:
      'linear-gradient(120deg, rgba(168, 85, 247, 0.18) 0%, rgba(126, 34, 206, 0.12) 45%, rgba(147, 51, 234, 0.18) 100%)',
    windShadow:
      '0 8px 22px rgba(168, 85, 247, 0.26), 0 2px 8px rgba(147, 51, 234, 0.2)',
    glow: 'rgba(192, 132, 252, 0.28)',
    hoverGlow: 'rgba(168, 85, 247, 0.45)',
    aura:
      'radial-gradient(ellipse at center, rgba(192, 132, 252, 0.5) 0%, rgba(147, 51, 234, 0.35) 45%, rgba(147, 51, 234, 0) 80%)',
    contentShadow: 'rgba(243, 232, 255, 0.75)',
    blade: 'linear-gradient(90deg, #ede9fe 0%, #ddd6fe 25%, #c4b5fd 55%, #a855f7 75%, #6b21a8 100%)',
    bladeShadow:
      '0 0 8px rgba(168, 85, 247, 0.35), 0 0 14px rgba(147, 51, 234, 0.28)',
    guard:
      'linear-gradient(135deg, rgba(134, 25, 143, 0.95) 0%, rgba(155, 48, 255, 0.9) 55%, rgba(126, 34, 206, 0.9) 100%)',
    guardShadow:
      '0 0 10px rgba(192, 132, 252, 0.5), 0 0 6px rgba(168, 85, 247, 0.45)',
    tip:
      'linear-gradient(115deg, rgba(237, 233, 254, 0.95) 0%, rgba(221, 214, 254, 0.9) 60%, rgba(196, 181, 253, 0.9) 100%)',
    tipShadow:
      '0 0 10px rgba(192, 132, 252, 0.55), 0 0 6px rgba(147, 51, 234, 0.45)',
  },
  {
    text: '#b91c1c',
    background:
      'linear-gradient(120deg, rgba(239, 68, 68, 0.18) 0%, rgba(220, 38, 38, 0.12) 45%, rgba(248, 113, 113, 0.18) 100%)',
    windShadow:
      '0 8px 22px rgba(248, 113, 113, 0.3), 0 2px 8px rgba(239, 68, 68, 0.24)',
    glow: 'rgba(248, 113, 113, 0.28)',
    hoverGlow: 'rgba(239, 68, 68, 0.45)',
    aura:
      'radial-gradient(ellipse at center, rgba(252, 165, 165, 0.5) 0%, rgba(248, 113, 113, 0.35) 45%, rgba(248, 113, 113, 0) 80%)',
    contentShadow: 'rgba(254, 226, 226, 0.75)',
    blade: 'linear-gradient(90deg, #fee2e2 0%, #fecaca 25%, #fca5a5 55%, #f87171 75%, #b91c1c 100%)',
    bladeShadow:
      '0 0 8px rgba(248, 113, 113, 0.4), 0 0 14px rgba(239, 68, 68, 0.32)',
    guard:
      'linear-gradient(135deg, rgba(190, 18, 60, 0.95) 0%, rgba(248, 113, 113, 0.9) 55%, rgba(239, 68, 68, 0.9) 100%)',
    guardShadow:
      '0 0 10px rgba(252, 165, 165, 0.5), 0 0 6px rgba(248, 113, 113, 0.45)',
    tip:
      'linear-gradient(115deg, rgba(254, 205, 211, 0.95) 0%, rgba(252, 165, 165, 0.9) 60%, rgba(248, 113, 113, 0.9) 100%)',
    tipShadow:
      '0 0 10px rgba(248, 113, 113, 0.55), 0 0 6px rgba(239, 68, 68, 0.45)',
  },
  {
    text: '#166534',
    background:
      'linear-gradient(120deg, rgba(74, 222, 128, 0.18) 0%, rgba(34, 197, 94, 0.12) 45%, rgba(22, 163, 74, 0.18) 100%)',
    windShadow:
      '0 8px 22px rgba(74, 222, 128, 0.26), 0 2px 8px rgba(22, 163, 74, 0.2)',
    glow: 'rgba(74, 222, 128, 0.25)',
    hoverGlow: 'rgba(34, 197, 94, 0.4)',
    aura:
      'radial-gradient(ellipse at center, rgba(74, 222, 128, 0.5) 0%, rgba(34, 197, 94, 0.32) 45%, rgba(34, 197, 94, 0) 80%)',
    contentShadow: 'rgba(220, 252, 231, 0.75)',
    blade: 'linear-gradient(90deg, #dcfce7 0%, #bbf7d0 25%, #86efac 55%, #4ade80 75%, #16a34a 100%)',
    bladeShadow:
      '0 0 8px rgba(74, 222, 128, 0.35), 0 0 14px rgba(34, 197, 94, 0.28)',
    guard:
      'linear-gradient(135deg, rgba(16, 185, 129, 0.95) 0%, rgba(22, 163, 74, 0.9) 55%, rgba(34, 197, 94, 0.9) 100%)',
    guardShadow:
      '0 0 10px rgba(74, 222, 128, 0.45), 0 0 6px rgba(34, 197, 94, 0.4)',
    tip:
      'linear-gradient(115deg, rgba(209, 250, 229, 0.95) 0%, rgba(134, 239, 172, 0.9) 60%, rgba(52, 211, 153, 0.9) 100%)',
    tipShadow:
      '0 0 10px rgba(74, 222, 128, 0.55), 0 0 6px rgba(34, 197, 94, 0.4)',
  },
  {
    text: '#1e3a8a',
    background:
      'linear-gradient(120deg, rgba(99, 102, 241, 0.18) 0%, rgba(59, 130, 246, 0.12) 45%, rgba(37, 99, 235, 0.18) 100%)',
    windShadow:
      '0 8px 22px rgba(129, 140, 248, 0.28), 0 2px 8px rgba(59, 130, 246, 0.22)',
    glow: 'rgba(99, 102, 241, 0.28)',
    hoverGlow: 'rgba(129, 140, 248, 0.45)',
    aura:
      'radial-gradient(ellipse at center, rgba(165, 180, 252, 0.5) 0%, rgba(99, 102, 241, 0.32) 45%, rgba(99, 102, 241, 0) 80%)',
    contentShadow: 'rgba(224, 231, 255, 0.75)',
    blade: 'linear-gradient(90deg, #e0e7ff 0%, #c7d2fe 25%, #a5b4fc 55%, #818cf8 75%, #4338ca 100%)',
    bladeShadow:
      '0 0 8px rgba(129, 140, 248, 0.35), 0 0 14px rgba(79, 70, 229, 0.28)',
    guard:
      'linear-gradient(135deg, rgba(67, 56, 202, 0.95) 0%, rgba(99, 102, 241, 0.9) 55%, rgba(129, 140, 248, 0.9) 100%)',
    guardShadow:
      '0 0 10px rgba(165, 180, 252, 0.5), 0 0 6px rgba(99, 102, 241, 0.45)',
    tip:
      'linear-gradient(115deg, rgba(224, 231, 255, 0.95) 0%, rgba(191, 219, 254, 0.9) 60%, rgba(148, 163, 254, 0.9) 100%)',
    tipShadow:
      '0 0 10px rgba(129, 140, 248, 0.55), 0 0 6px rgba(99, 102, 241, 0.4)',
  },
  {
    text: '#0f172a',
    background:
      'linear-gradient(120deg, rgba(148, 163, 184, 0.2) 0%, rgba(100, 116, 139, 0.12) 45%, rgba(71, 85, 105, 0.2) 100%)',
    windShadow:
      '0 8px 22px rgba(148, 163, 184, 0.3), 0 2px 8px rgba(94, 234, 212, 0.24)',
    glow: 'rgba(148, 163, 184, 0.28)',
    hoverGlow: 'rgba(94, 234, 212, 0.4)',
    aura:
      'radial-gradient(ellipse at center, rgba(148, 163, 184, 0.5) 0%, rgba(94, 234, 212, 0.35) 45%, rgba(148, 163, 184, 0) 80%)',
    contentShadow: 'rgba(226, 232, 240, 0.75)',
    blade: 'linear-gradient(90deg, #f1f5f9 0%, #e2e8f0 25%, #cbd5f5 55%, #a5b4fc 75%, #475569 100%)',
    bladeShadow:
      '0 0 8px rgba(148, 163, 184, 0.35), 0 0 14px rgba(94, 234, 212, 0.25)',
    guard:
      'linear-gradient(135deg, rgba(51, 65, 85, 0.95) 0%, rgba(148, 163, 184, 0.9) 55%, rgba(94, 234, 212, 0.85) 100%)',
    guardShadow:
      '0 0 10px rgba(148, 163, 184, 0.45), 0 0 6px rgba(94, 234, 212, 0.4)',
    tip:
      'linear-gradient(115deg, rgba(226, 232, 240, 0.95) 0%, rgba(191, 219, 254, 0.9) 60%, rgba(94, 234, 212, 0.9) 100%)',
    tipShadow:
      '0 0 10px rgba(94, 234, 212, 0.5), 0 0 6px rgba(148, 163, 184, 0.4)',
  },
  {
    text: '#831843',
    background:
      'linear-gradient(120deg, rgba(244, 114, 182, 0.18) 0%, rgba(236, 72, 153, 0.12) 45%, rgba(219, 39, 119, 0.18) 100%)',
    windShadow:
      '0 8px 22px rgba(244, 114, 182, 0.3), 0 2px 8px rgba(236, 72, 153, 0.24)',
    glow: 'rgba(244, 114, 182, 0.3)',
    hoverGlow: 'rgba(236, 72, 153, 0.45)',
    aura:
      'radial-gradient(ellipse at center, rgba(249, 168, 212, 0.5) 0%, rgba(236, 72, 153, 0.35) 45%, rgba(236, 72, 153, 0) 80%)',
    contentShadow: 'rgba(253, 242, 248, 0.8)',
    blade: 'linear-gradient(90deg, #fce7f3 0%, #fbcfe8 25%, #f9a8d4 55%, #f472b6 75%, #db2777 100%)',
    bladeShadow:
      '0 0 8px rgba(244, 114, 182, 0.4), 0 0 14px rgba(219, 39, 119, 0.32)',
    guard:
      'linear-gradient(135deg, rgba(190, 24, 93, 0.95) 0%, rgba(236, 72, 153, 0.9) 55%, rgba(244, 114, 182, 0.9) 100%)',
    guardShadow:
      '0 0 10px rgba(244, 114, 182, 0.5), 0 0 6px rgba(236, 72, 153, 0.45)',
    tip:
      'linear-gradient(115deg, rgba(251, 207, 232, 0.95) 0%, rgba(249, 168, 212, 0.9) 60%, rgba(244, 114, 182, 0.9) 100%)',
    tipShadow:
      '0 0 10px rgba(244, 114, 182, 0.55), 0 0 6px rgba(219, 39, 119, 0.45)',
  },
]

const swordWindClips: ReadonlyArray<string> = [
  'polygon(0% 65%, 16% 50%, 36% 38%, 54% 30%, 78% 24%, 100% 0%, 100% 56%, 86% 70%, 64% 86%, 34% 94%, 0% 80%)',
  'polygon(0% 68%, 18% 52%, 34% 40%, 52% 31%, 74% 24%, 98% 10%, 100% 58%, 84% 72%, 60% 88%, 28% 95%, 0% 82%)',
  'polygon(0% 62%, 20% 48%, 40% 34%, 58% 28%, 76% 22%, 100% 8%, 98% 60%, 80% 74%, 58% 88%, 30% 94%, 0% 78%)',
  'polygon(0% 70%, 14% 55%, 32% 42%, 50% 32%, 70% 26%, 100% 12%, 100% 60%, 86% 76%, 64% 90%, 32% 96%, 0% 84%)',
  'polygon(0% 64%, 18% 46%, 38% 36%, 56% 30%, 78% 24%, 100% 6%, 100% 54%, 86% 70%, 62% 86%, 34% 94%, 0% 82%)',
  'polygon(0% 69%, 12% 52%, 28% 40%, 46% 32%, 66% 26%, 96% 14%, 100% 58%, 84% 72%, 60% 88%, 28% 96%, 0% 84%)',
]

const pseudoRandom = (seed: number): number => {
  const x = Math.sin(seed * 12.9898) * 43758.5453
  return x - Math.floor(x)
}

const createRandomSeries = (index: number): ((offset: number) => number) => {
  const base = index + 1
  return (offset: number): number => pseudoRandom(base * 13.37 + offset * 17.17)
}

export function applySwordDeletePalette(): void {
  if (typeof document === 'undefined') return
  const swords = document.querySelectorAll<HTMLElement>(
    '.yozora-heading .yozora-delete, h1.yozora-root .yozora-delete',
  )
  if (swords.length <= 0) return

  swords.forEach((element, index) => {
    const palette = swordPalettes[index % swordPalettes.length]
    const rand = createRandomSeries(index)
    const rotate = -8 + rand(0.21) * 6.5
    const skew = -7 + rand(0.43) * 6.2
    const scaleX = 0.92 + rand(0.65) * 0.32
    const offset = -52 + rand(0.87) * 9
    const opacity = 0.72 + rand(1.07) * 0.26
    const hoverOffset = 1.1 + rand(1.23) * 1.8
    const hoverRotate = 0.6 + rand(1.39) * 1.8
    const hoverSkew = 0.4 + rand(1.51) * 1.6
    const hoverScale = 0.045 + rand(1.73) * 0.085
    const saturation = 1.15 + rand(1.91) * 0.28
    const hoverSaturation = saturation + 0.18 + rand(2.13) * 0.22
    const auraBlur = 4 + rand(2.31) * 4.5
    const auraDuration = 3 + rand(2.47) * 2.4
    const bladeDuration = 2.3 + rand(2.61) * 2.4

    element.style.setProperty('--sword-text-color', palette.text)
    element.style.setProperty('--sword-bg', 'transparent')
    element.style.setProperty('--sword-wind-bg', palette.background)
    element.style.setProperty('--sword-wind-shadow', palette.windShadow)
    element.style.setProperty('--sword-glow-color', palette.glow)
    element.style.setProperty('--sword-hover-glow-color', palette.hoverGlow)
    element.style.setProperty('--sword-aura-bg', palette.aura)
    element.style.setProperty('--sword-content-shadow', palette.contentShadow)
    element.style.setProperty('--sword-blade-bg', palette.blade)
    element.style.setProperty('--sword-blade-shadow', palette.bladeShadow)
    element.style.setProperty('--sword-guard-bg', palette.guard)
    element.style.setProperty('--sword-guard-shadow', palette.guardShadow)
    element.style.setProperty('--sword-tip-bg', palette.tip)
    element.style.setProperty('--sword-tip-shadow', palette.tipShadow)
    element.style.setProperty('--sword-wind-clip', swordWindClips[index % swordWindClips.length])
    element.style.setProperty('--sword-wind-offset', `${offset.toFixed(2)}%`)
    element.style.setProperty('--sword-wind-rotate', `${rotate.toFixed(2)}deg`)
    element.style.setProperty('--sword-wind-skew', `${skew.toFixed(2)}deg`)
    element.style.setProperty('--sword-wind-scale-x', scaleX.toFixed(3))
    element.style.setProperty('--sword-wind-opacity', opacity.toFixed(2))
    element.style.setProperty('--sword-wind-hover-offset-delta', `${hoverOffset.toFixed(2)}%`)
    element.style.setProperty('--sword-wind-hover-rotate', `${hoverRotate.toFixed(2)}deg`)
    element.style.setProperty('--sword-wind-hover-skew', `${hoverSkew.toFixed(2)}deg`)
    element.style.setProperty('--sword-wind-hover-scale', hoverScale.toFixed(3))
    element.style.setProperty('--sword-wind-saturation', saturation.toFixed(2))
    element.style.setProperty('--sword-wind-hover-saturation', hoverSaturation.toFixed(2))
    element.style.setProperty('--sword-aura-blur', `${auraBlur.toFixed(2)}px`)
    element.style.setProperty('--sword-aura-duration', `${auraDuration.toFixed(2)}s`)
    element.style.setProperty('--sword-blade-duration', `${bladeDuration.toFixed(2)}s`)
    element.dataset.swordIndex = `${index + 1}`
  })
}
