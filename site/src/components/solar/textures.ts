import * as THREE from 'three'
import type { TextureKind } from '../../data/site'

const BASE: Record<TextureKind, string> = {
  earth: '#3f6f96',
  moon: '#b3ada0',
  mars: '#b25a3e',
  mercury: '#978b7c',
  jupiter: '#c99d6d',
}

function makeCanvas(): CanvasRenderingContext2D | null {
  const canvas = document.createElement('canvas')
  canvas.width = 256
  canvas.height = 128
  return canvas.getContext('2d')
}

function blotches(
  ctx: CanvasRenderingContext2D,
  color: string,
  count: number,
  radiusMin: number,
  radiusMax: number,
  alpha: number,
) {
  ctx.globalAlpha = alpha
  ctx.fillStyle = color
  for (let i = 0; i < count; i += 1) {
    const radius = radiusMin + Math.random() * (radiusMax - radiusMin)
    ctx.beginPath()
    ctx.arc(Math.random() * 256, Math.random() * 128, radius, 0, Math.PI * 2)
    ctx.fill()
  }
  ctx.globalAlpha = 1
}

// 程序化生成的星球表面:低多边形感的斑驳,不依赖任何外部素材。
export function createPlanetTexture(kind: TextureKind): THREE.CanvasTexture | null {
  const ctx = makeCanvas()
  if (!ctx) return null
  const canvas = ctx.canvas

  ctx.fillStyle = BASE[kind]
  ctx.fillRect(0, 0, canvas.width, canvas.height)

  switch (kind) {
    case 'earth':
      blotches(ctx, '#4d7f52', 26, 6, 16, 0.85)
      blotches(ctx, '#e9f2f5', 10, 3, 9, 0.8)
      blotches(ctx, '#2c5875', 18, 5, 14, 0.45)
      break
    case 'moon':
      blotches(ctx, '#8d887c', 30, 2, 7, 0.5)
      blotches(ctx, '#d9d4c9', 16, 2, 5, 0.35)
      break
    case 'mars':
      blotches(ctx, '#8f4429', 26, 4, 12, 0.45)
      blotches(ctx, '#d98a5e', 14, 2, 6, 0.35)
      break
    case 'mercury':
      blotches(ctx, '#776d5f', 34, 2, 6, 0.5)
      blotches(ctx, '#bdb3a3', 18, 2, 4, 0.4)
      break
    case 'jupiter': {
      const bands = ['#d9b184', '#b98a5c', '#e2c39a', '#a97a4e']
      let y = 0
      let index = 0
      ctx.globalAlpha = 0.55
      while (y < 128) {
        const height = 6 + ((index * 7) % 10)
        ctx.fillStyle = bands[index % bands.length]
        ctx.fillRect(0, y, 256, height)
        y += height
        index += 1
      }
      ctx.globalAlpha = 1
      blotches(ctx, '#f2e2c9', 8, 3, 8, 0.5)
      break
    }
  }

  const texture = new THREE.CanvasTexture(canvas)
  texture.colorSpace = THREE.SRGBColorSpace
  texture.anisotropy = 4
  return texture
}

// 中心恒星的光晕贴图。
export function createGlowTexture(): THREE.CanvasTexture | null {
  const canvas = document.createElement('canvas')
  canvas.width = 256
  canvas.height = 256
  const ctx = canvas.getContext('2d')
  if (!ctx) return null
  const gradient = ctx.createRadialGradient(128, 128, 8, 128, 128, 128)
  gradient.addColorStop(0, 'rgba(255, 220, 160, 0.95)')
  gradient.addColorStop(0.35, 'rgba(255, 190, 110, 0.42)')
  gradient.addColorStop(1, 'rgba(255, 190, 110, 0)')
  ctx.fillStyle = gradient
  ctx.fillRect(0, 0, 256, 256)
  const texture = new THREE.CanvasTexture(canvas)
  texture.colorSpace = THREE.SRGBColorSpace
  return texture
}
