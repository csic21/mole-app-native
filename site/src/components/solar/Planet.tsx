import { useEffect, useMemo, useRef } from 'react'
import * as THREE from 'three'
import { useFrame } from '@react-three/fiber'
import { createPlanetTexture } from './textures'
import type { BodyDef } from '../../data/site'

type PlanetProps = {
  body: BodyDef
  selected: boolean
  hovered: boolean
  reduceMotion: boolean
  onHover: (id: string | null) => void
  onSelect: (id: string) => void
}

export function Planet({ body, selected, hovered, reduceMotion, onHover, onSelect }: PlanetProps) {
  const orbitAnchor = useRef<THREE.Group>(null)
  const mesh = useRef<THREE.Mesh>(null)

  const texture = useMemo(
    () => (body.texture ? createPlanetTexture(body.texture) : null),
    [body.texture],
  )

  useEffect(
    () => () => {
      texture?.dispose()
    },
    [texture],
  )

  useFrame((state, delta) => {
    const angle = body.phase + state.clock.elapsedTime * (reduceMotion ? 0 : body.orbitSpeed)
    if (orbitAnchor.current) {
      orbitAnchor.current.position.set(Math.cos(angle) * body.orbit, 0, Math.sin(angle) * body.orbit)
    }
    if (mesh.current) {
      mesh.current.rotation.y += delta * (reduceMotion ? 0.06 : body.spin)
      const focus = selected ? 1.22 : hovered ? 1.14 : 1
      const target = body.size * focus
      const next = THREE.MathUtils.lerp(mesh.current.scale.x, target, Math.min(1, delta * 6))
      mesh.current.scale.setScalar(next)
    }
  })

  return (
    <group>
      <mesh rotation-x={-Math.PI / 2} position-y={-0.01}>
        <ringGeometry args={[body.orbit - 0.008, body.orbit + 0.008, 160]} />
        <meshBasicMaterial
          color={body.ringColor}
          transparent
          opacity={selected || hovered ? 0.5 : 0.16}
          side={THREE.DoubleSide}
        />
      </mesh>
      <group ref={orbitAnchor} position={[Math.cos(body.phase) * body.orbit, 0, Math.sin(body.phase) * body.orbit]}>
        <mesh
          ref={mesh}
          scale={body.size}
          onPointerOver={(event) => {
            event.stopPropagation()
            onHover(body.id)
            document.body.style.cursor = 'pointer'
          }}
          onPointerOut={() => {
            onHover(null)
            document.body.style.cursor = ''
          }}
          onClick={(event) => {
            event.stopPropagation()
            onSelect(body.id)
          }}
        >
          <sphereGeometry args={[1, 48, 48]} />
          <meshStandardMaterial
            map={texture ?? undefined}
            color={texture ? '#ffffff' : body.color}
            roughness={0.85}
            metalness={0.05}
          />
        </mesh>
      </group>
    </group>
  )
}
