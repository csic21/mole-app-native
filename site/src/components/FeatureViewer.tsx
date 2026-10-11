import { useState } from 'react'
import { ALL_BODIES, getBody, type MockKind } from '../data/site'
import { MenubarMock } from './tool/MenubarMock'
import { MockPage } from './mocks/MockPages'

// 把标签状态写进 hash(#feature-clean …),每个功能都有可分享的一"页"。
function initialTab(): string {
  const match = window.location.hash.match(/^#feature-([a-z]+)$/)
  if (match && ALL_BODIES.some((body) => body.id === match[1])) return match[1]
  return 'clean'
}

export function FeatureViewer() {
  const [active, setActive] = useState(initialTab)
  const body = getBody(active)
  const isMenubar = body.id === 'menubar'

  const select = (id: string) => {
    setActive(id)
    window.history.replaceState(null, '', `#feature-${id}`)
  }

  const step = (direction: 1 | -1) => {
    const index = ALL_BODIES.findIndex((item) => item.id === active)
    const next = ALL_BODIES[(index + direction + ALL_BODIES.length) % ALL_BODIES.length]
    select(next.id)
  }

  return (
    <section className="viewer" id="features">
      <div className="shell">
        <p className="section-tag">01 · 功能</p>
        <h2 className="section-title">五件工具,各守一颗星</h2>
        <p className="section-lead">
          点下面的标签,看每一件工具的页面还原——每个标签上的内容都不一样;
          想动手时,「看这一页」会进入对应页面,再去原版 Mole 看真东西。
        </p>

        <div className={`viewer-window mk-win-${body.id}`}>
          <div className="mk-topbar">
            <span className="mk-lights" aria-hidden="true">
              <i />
              <i />
              <i />
            </span>
            <span className="mk-logo" aria-hidden="true" />
            <div className="mk-pagetabs">
              {ALL_BODIES.filter((item) => item.id !== 'menubar').map((item) => (
                <span
                  key={item.id}
                  className={`mk-pagetab ${item.id === active ? 'is-active' : ''}`}
                >
                  {item.role}
                </span>
              ))}
            </div>
          </div>
          <div className="viewer-swap" key={`swap-${active}`}>
            {isMenubar ? <MenubarMock /> : <MockPage kind={body.id as MockKind} />}
          </div>
        </div>

        <div className="viewer-foot">
          <p className="viewer-caption" key={`cap-${active}`}>
            {body.role} · {body.poem}
            <a className="viewer-inline-link" href={`#/${body.id}`}>
              看这一页 →
            </a>
          </p>
          <div
            className="pill-row"
            role="tablist"
            aria-label="功能切换"
            onKeyDown={(event) => {
              if (event.key === 'ArrowRight') {
                event.preventDefault()
                step(1)
              } else if (event.key === 'ArrowLeft') {
                event.preventDefault()
                step(-1)
              }
            }}
          >
            {ALL_BODIES.map((item) => (
              <button
                key={item.id}
                type="button"
                role="tab"
                aria-selected={item.id === active}
                className={`pill ${item.id === active ? 'is-active' : ''}`}
                onClick={() => select(item.id)}
              >
                {item.role}
              </button>
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
