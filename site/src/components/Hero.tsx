export function Hero() {
  return (
    <section className="hero" id="top">
      <div className="shell hero-inner">
        <p className="hero-note">风格研究项目 · 致敬 mole.fit · 非官方</p>
        <h1 className="hero-title">
          让散落的字节,
          <br />
          回到各自的轨道
        </h1>
        <p className="hero-lead">
          参考 mole.fit 的视觉语言搭起来的 3D 星球着陆页:六颗星体,
          各自照看缓存、AI 数据、软件、优化、分析与状态。
        </p>
        <div className="hero-cta">
          <a className="btn btn-primary btn-lg" href="#solar">
            看看这颗太阳系
          </a>
          <a
            className="btn btn-ghost btn-lg"
            href="https://mole.fit"
            target="_blank"
            rel="noreferrer"
          >
            了解原版 Mole
          </a>
        </div>
        <dl className="hero-stats">
          <div>
            <dt>星体</dt>
            <dd>6 颗</dd>
          </div>
          <div>
            <dt>工具</dt>
            <dd>5 件</dd>
          </div>
          <div>
            <dt>渲染</dt>
            <dd>Three.js</dd>
          </div>
          <div>
            <dt>协议</dt>
            <dd>MIT</dd>
          </div>
        </dl>
      </div>
      <div className="hero-glow" aria-hidden="true" />
    </section>
  )
}
