import { useEffect, useMemo, useRef } from 'react'
import * as THREE from 'three'
import { Canvas, useFrame } from '@react-three/fiber'
import { createGlowTexture, createPlanetTexture } from '../solar/textures'
import type { TextureKind } from '../../data/site'

export type OrbKind = TextureKind | 'sun'

function OrbMesh({ kind, reduceMotion }: { kind: OrbKind; reduceMotion: boolean }) {
  const mesh = useRef<THREE.Mesh>(null)
  const texture = useMemo(() => (kind === 'sun' ? null : createPlanetTexture(kind)), [kind])
  const glow = useMemo(() => (kind === 'sun' ? createGlowTexture() : null), [kind])

  useEffect(
    () => () => {
      texture?.dispose()
      glow?.dispose()
    },
    [texture, glow],
  )

  useFrame((state, delta) => {
    if (!mesh.current) return
    mesh.current.rotation.y += delta * (reduceMotion ? 0.015 : 0.09)
    if (!reduceMotion) {
      mesh.current.position.y = Math.sin(state.clock.elapsedTime * 0.5) * 0.06
    }
  })

  return (
    <group>
      <mesh ref={mesh} scale={1.75}>
        <sphereGeometry args={[1, 64, 64]} />
        {kind === 'sun' ? (
          <meshStandardMaterial
            color="#f4b359"
            emissive="#f08c2a"
            emissiveIntensity={1.4}
            roughness={1}
          />
        ) : (
          <meshStandardMaterial map={texture ?? undefined} roughness={0.9} metalness={0.05} />
        )}
      </mesh>
      {kind === 'sun' && (
        <sprite scale={[6.6, 6.6, 1]}>
          <spriteMaterial
            map={glow ?? undefined}
            color="#ffca7a"
            transparent
            opacity={0.6}
            depthWrite={false}
          />
        </sprite>
      )}
    </group>
  )
}

// 功能阅览器里的"雕塑":暗场中的一颗大星球,慢速自转、轻微浮动。
export function FeatureOrb({ kind, reduceMotion }: { kind: OrbKind; reduceMotion: boolean }) {
  return (
    <Canvas
      dpr={[1, 1.75]}
      camera={{ position: [0, 0, 5.8], fov: 38 }}
      gl={{ antialias: true, alpha: true }}
    >
      <ambientLight intensity={0.26} />
      <directionalLight position={[3, 2.4, 4]} intensity={1.55} color="#fff1e0" />
      <directionalLight position={[-4.5, -2, -3]} intensity={0.4} color="#8fa8c9" />
      <OrbMesh kind={kind} reduceMotion={reduceMotion} />
    </Canvas>
  )
}
