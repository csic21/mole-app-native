export function Footer() {
  return (
    <footer className="footer" id="about">
      <div className="shell footer-grid">
        <div className="footer-note">
          <p className="footer-brand">
            <span className="nav-mark" aria-hidden="true" />
            mole-fit-study
          </p>
          <p>
            这是一个致敬 mole.fit 的视觉风格研究项目,与 Mole 官方没有任何关联。
            页面文案与图形均为本仓库原创占位;设计灵感来自 mole.fit 的公开页面,
            仅作学习用途。
          </p>
        </div>
        <nav className="footer-links" aria-label="相关链接">
          <a href="https://github.com/csic21/mole-fit-study" target="_blank" rel="noreferrer">
            源码仓库
          </a>
          <a href="https://mole.fit" target="_blank" rel="noreferrer">
            原版 Mole
          </a>
          <a
            href="https://github.com/csic21/mole-fit-study/blob/main/LICENSE"
            target="_blank"
            rel="noreferrer"
          >
            MIT 许可证
          </a>
        </nav>
      </div>
      <div className="shell footer-base">
        <span>© 2026 mole-fit-study</span>
        <span>React · Three.js · 无图片素材</span>
      </div>
    </footer>
  )
}
