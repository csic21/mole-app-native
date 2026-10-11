// "菜单栏"标签:常驻下拉面板还原(指标卡 + 高占用进程 + 清理记录)。
export function MenubarMock() {
  const cards = [
    { label: 'CPU', extra: '46°C', value: '11 %', note: '低负载 · 负载 2.4 / 18' },
    { label: 'GPU', extra: '44°C', value: '13 %', note: '低负载 · 20 核' },
    { label: '内存', extra: '压力 29%', value: '71 %', note: '34.08 GB / 48 GB' },
    { label: '磁盘', extra: '995 GB', value: '292 GB', note: '已用 703 GB · 71%' },
    { label: '网络', extra: 'Wi-Fi', value: '166 KB/s', note: '↑ 163K · ↓ 3K' },
    { label: '风扇', extra: '负载 0%', value: '0 RPM', note: '由 macOS 调节' },
  ]
  const procs = [
    { app: 'Parallels Desktop', mem: '14.32 GB', cpu: '33.4 %' },
    { app: 'Claude', mem: '4.22 GB', cpu: '7.1 %' },
    { app: 'Cursor', mem: '2.09 GB', cpu: '38.5 %' },
  ]
  return (
    <div className="mk-dropdown" role="img" aria-label="菜单栏下拉面板示意">
      <div className="mk-dd-head">
        <span className="mk-dd-title">✳ 100 很好</span>
        <p className="mk-desc is-dim">M4 Pro · 32GB · macOS 26 · 已运行 13 小时</p>
      </div>
      <div className="mk-dd-cards">
        {cards.map((card) => (
          <div className="mk-dd-card" key={card.label}>
            <div className="mk-scard-head">
              <span>{card.label}</span>
              <em>{card.extra}</em>
            </div>
            <p className="mk-big is-small">{card.value}</p>
            <p className="mk-desc is-dim">{card.note}</p>
          </div>
        ))}
      </div>
      <p className="mk-side-label">高占用进程</p>
      {procs.map((proc) => (
        <div className="mk-dd-row" key={proc.app}>
          <span className="mk-name">{proc.app}</span>
          <span className="mk-size is-inline">{proc.mem}</span>
          <span className="mk-size is-dim">{proc.cpu} …</span>
        </div>
      ))}
      <div className="mk-dd-stats">
        <div>
          <b>2 TB</b>
          <i>已清理</i>
        </div>
        <div>
          <b>1042</b>
          <i>已卸载</i>
        </div>
        <div>
          <b>1835</b>
          <i>已优化</i>
        </div>
      </div>
    </div>
  )
}
