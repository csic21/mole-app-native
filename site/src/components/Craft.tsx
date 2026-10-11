export function Craft() {
  const items = [
    {
      title: '程序化材质',
      body: '五颗行星的斑驳、条纹与极冠都是运行时用 Canvas 生成的,仓库里没有一张图片素材。',
    },
    {
      title: '一块画布',
      body: '整个太阳系共用一块 WebGL 画布,DPR 封顶 1.75,星尘与轨道都是廉价的几何体。',
    },
    {
      title: '安静的动效',
      body: '系统开启"减弱动态效果"时轨道会停下、只保留自转;离开视口后画面不再重绘。',
    },
  ]
  return (
    <section className="craft" id="craft">
      <div className="shell">
        <p className="section-tag">03 · 设计</p>
        <h2 className="section-title">动效只花在值得的地方</h2>
        <div className="craft-grid">
          {items.map((item) => (
            <article className="craft-item" key={item.title}>
              <h3>{item.title}</h3>
              <p>{item.body}</p>
            </article>
          ))}
        </div>
      </div>
    </section>
  )
}
