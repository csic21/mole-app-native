import { useEffect, useMemo, useRef, useState } from 'react'
import * as THREE from 'three'
import { Canvas, useFrame } from '@react-three/fiber'
import { Planet } from './Planet'
import { createGlowTexture } from './textures'
import { PLANETS, SOLAR_BODIES, SUN, getBody } from '../../data/site'
import { useReducedMotion } from '../../hooks/useReducedMotion'

function Starfield() {
  const points = useRef<THREE.Points>(null)
  const positions = useMemo(() => {
    const count = 420
    const array = new Float32Array(count * 3)
    for (let i = 0; i < count; i += 1) {
      const radius = 15 + Math.random() * 22
      const theta = Math.random() * Math.PI * 2
      const phi = Math.acos(2 * Math.random() - 1)
      array[i * 3] = radius * Math.sin(phi) * Math.cos(theta)
      array[i * 3 + 1] = radius * Math.cos(phi) * 0.65
      array[i * 3 + 2] = radius * Math.sin(phi) * Math.sin(theta)
    }
    return array
  }, [])

  useFrame((_, delta) => {
    if (points.current) points.current.rotation.y += delta * 0.004
  })

  return (
    <points ref={points}>
      <bufferGeometry>
        <bufferAttribute attach="attributes-position" args={[positions, 3]} />
      </bufferGeometry>
      <pointsMaterial
        size={0.06}
        sizeAttenuation
        color="#efe8d8"
        transparent
        opacity={0.7}
        depthWrite={false}
      />
    </points>
  )
}

type SunProps = {
  reduceMotion: boolean
  selected: boolean
  hovered: boolean
  onHover: (id: string | null) => void
  onSelect: (id: string) => void
}

function Sun({ reduceMotion, selected, hovered, onHover, onSelect }: SunProps) {
  const mesh = useRef<THREE.Mesh>(null)
  const glowTexture = useMemo(() => createGlowTexture(), [])

  useEffect(
    () => () => {
      glowTexture?.dispose()
    },
    [glowTexture],
  )

  useFrame((_, delta) => {
    if (mesh.current) {
      mesh.current.rotation.y += delta * (reduceMotion ? 0 : SUN.spin)
      const focus = selected ? 1.12 : hovered ? 1.06 : 1
      const next = THREE.MathUtils.lerp(mesh.current.scale.x, SUN.size * focus, Math.min(1, delta * 6))
      mesh.current.scale.setScalar(next)
    }
  })

  return (
    <group>
      <mesh
        ref={mesh}
        scale={SUN.size}
        onPointerOver={(event) => {
          event.stopPropagation()
          onHover(SUN.id)
          document.body.style.cursor = 'pointer'
        }}
        onPointerOut={() => {
          onHover(null)
          document.body.style.cursor = ''
        }}
        onClick={(event) => {
          event.stopPropagation()
          onSelect(SUN.id)
        }}
      >
        <sphereGeometry args={[1, 48, 48]} />
        <meshStandardMaterial
          color="#f4b359"
          emissive="#f08c2a"
          emissiveIntensity={1.5}
          roughness={1}
        />
      </mesh>
      <sprite scale={[4.4, 4.4, 1]}>
        <spriteMaterial
          map={glowTexture ?? undefined}
          color="#ffca7a"
          transparent
          opacity={0.72}
          depthWrite={false}
        />
      </sprite>
      <pointLight color="#ffd9a0" intensity={2.6} distance={44} decay={1.6} />
    </group>
  )
}

function Rig({ reduceMotion }: { reduceMotion: boolean }) {
  useFrame((state) => {
    if (reduceMotion) return
    const { camera, pointer } = state
    camera.position.x = THREE.MathUtils.lerp(camera.position.x, pointer.x * 0.9, 0.05)
    camera.position.y = THREE.MathUtils.lerp(camera.position.y, 6.8 + pointer.y * 0.6, 0.05)
    camera.lookAt(0, 0, 0)
  })
  return null
}

type SolarSystemProps = {
  selected: string
  onSelect: (id: string) => void
}

export function SolarSystem({ selected, onSelect }: SolarSystemProps) {
  const [hovered, setHovered] = useState<string | null>(null)
  const reduceMotion = useReducedMotion()
  const active = getBody(selected)
  const hoveredBody = hovered ? getBody(hovered) : null

  return (
    <section className="cosmos" id="solar">
      <div className="shell cosmos-grid">
        <div className="cosmos-stage" aria-label="可交互的三维太阳系">
          <Canvas
            dpr={[1, 1.75]}
            camera={{ position: [0, 6.8, 13.4], fov: 42 }}
            gl={{ antialias: true, alpha: true }}
          >
            <ambientLight intensity={0.38} />
            <Starfield />
            <Rig reduceMotion={reduceMotion} />
            <Sun
              reduceMotion={reduceMotion}
              selected={selected === SUN.id}
              hovered={hovered === SUN.id}
              onHover={setHovered}
              onSelect={onSelect}
            />
            {PLANETS.map((planet) => (
              <Planet
                key={planet.id}
                body={planet}
                selected={planet.id === selected}
                hovered={planet.id === hovered}
                reduceMotion={reduceMotion}
                onHover={setHovered}
                onSelect={onSelect}
              />
            ))}
          </Canvas>
          <p className="cosmos-hud" aria-live="polite">
            {hoveredBody ? (
              <>
                <span className="cosmos-hud-dot" style={{ background: hoveredBody.color }} />
                {hoveredBody.name} · {hoveredBody.role}
              </>
            ) : (
              '悬停查看星体,点击切换详情'
            )}
          </p>
        </div>

        <aside className="cosmos-panel">
          <p className="section-tag">02 · 太阳系</p>
          <h2 className="cosmos-title">行星各循其轨</h2>
          <p className="cosmos-lead">点一颗星球,看它照看 Mac 的哪一面。</p>

          <div className="pill-row" role="tablist" aria-label="选择星体">
            {SOLAR_BODIES.map((body) => (
              <button
                key={body.id}
                type="button"
                role="tab"
                aria-selected={body.id === selected}
                className={`pill ${body.id === selected ? 'is-active' : ''}`}
                onClick={() => onSelect(body.id)}
                onMouseEnter={() => setHovered(body.id)}
                onMouseLeave={() => setHovered(null)}
              >
                {body.role}
              </button>
            ))}
          </div>

          <article className="cosmos-card" key={active.id}>
            <p className="cosmos-card-name" style={{ color: active.ringColor }}>
              {active.name} · {active.role}
            </p>
            <h3 className="cosmos-card-title">{active.title}</h3>
            <p className="cosmos-card-blurb">{active.blurb}</p>
            <ul className="cosmos-card-list">
              {active.bullets.map((item) => (
                <li key={item}>{item}</li>
              ))}
            </ul>
            <p className="cosmos-card-poem">{active.poem}</p>
          </article>
        </aside>
      </div>
    </section>
  )
}
