import { Suspense, lazy } from 'react'
import { ALL_BODIES, getBody } from '../data/site'
import { useReducedMotion } from '../hooks/useReducedMotion'
import { MenubarMock } from './tool/MenubarMock'
import type { OrbKind } from './viewer/FeatureOrb'

const FeatureOrb = lazy(() =>
  import('./viewer/FeatureOrb').then((module) => ({ default: module.FeatureOrb })),
)

// 每个工具自己的页面:#/clean、#/optimize … 直达、可分享、可返回。
export function ToolPage({ id }: { id: string }) {
  const body = getBody(id)
  const reduceMotion = useReducedMotion()
  const isMenubar = body.id === 'menubar'

  return (
    <section className="tool-page">
      <div className="shell tool-shell">
        <a className="tool-back" href="#/">
          ← 返回首页
        </a>
        <p className="section-tag">{body.role} · 专属场景</p>
        <h1 className="tool-title">{body.title}</h1>
        <p className="tool-blurb">{body.blurb}</p>

        <div className="tool-stage" key={id}>
          <div className={`tool-visual ${isMenubar ? 'is-bar' : ''}`}>
            {isMenubar ? (
              <MenubarMock />
            ) : (
              <Suspense fallback={null}>
                <FeatureOrb kind={(body.texture ?? 'sun') as OrbKind} reduceMotion={reduceMotion} />
              </Suspense>
            )}
          </div>
          <p className="viewer-verse">{body.verse}</p>
        </div>

        <ul className="tool-list">
          {body.bullets.map((item) => (
            <li key={item}>{item}</li>
          ))}
        </ul>

        <div className="tool-actions">
          <a
            className="btn btn-primary btn-lg"
            href={body.ctaHref}
            target="_blank"
            rel="noreferrer"
          >
            在原版 Mole 中体验
          </a>
          <a className="btn btn-ghost btn-lg" href="#/">
            回到功能概览
          </a>
        </div>

        <div className="tool-switch">
          <span className="tool-switch-label">其他工具</span>
          <div className="pill-row">
            {ALL_BODIES.filter((item) => item.id !== body.id).map((item) => (
              <a key={item.id} className="pill" href={`#/${item.id}`}>
                {item.role}
              </a>
            ))}
            <a className="pill" href="#solar">
              太阳系
            </a>
          </div>
        </div>
      </div>
    </section>
  )
}
