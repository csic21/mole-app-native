const LINKS = [
  { href: '#features', label: '功能' },
  { href: '#solar', label: '太阳系' },
  { href: '#craft', label: '设计' },
  { href: '#about', label: '关于' },
]

export function Nav() {
  return (
    <header className="nav">
      <div className="nav-inner">
        <a className="nav-brand" href="#top" aria-label="回到顶部">
          <span className="nav-mark" aria-hidden="true" />
          <span className="nav-word">
            Mole
            <em>·研究</em>
          </span>
        </a>
        <nav className="nav-links" aria-label="页面导航">
          {LINKS.map((link) => (
            <a key={link.href} href={link.href}>
              {link.label}
            </a>
          ))}
        </nav>
        <div className="nav-actions">
          <a
            className="btn btn-quiet"
            href="https://github.com/csic21/mole-fit-study"
            target="_blank"
            rel="noreferrer"
          >
            看源码
          </a>
          <a className="btn btn-primary" href="#solar">
            去看星球
          </a>
        </div>
      </div>
    </header>
  )
}
