# mole-fit-study

一个**学习性质的落地页项目**:参考 [mole.fit](https://mole.fit) 的视觉风格,
用 React + Three.js 从零搭一个带 3D 星球动效的单页站点。

> 本项目与 Mole 官方没有任何关联。页面文案与图形均为本仓库原创占位,
> 未使用 mole.fit 的图片、Logo 或受版权保护的文案;设计风格仅作学习参考。
> 示例中的界面示意图是 CSS 手绘的,不是真实产品截图。

## 它长什么样

- **米白纸面 + 深空黑**的两段式配色:正文安静,唯一的"喧闹"留给星球
- **功能阅览器**:暗场应用大窗里,每个标签还原一张对应的软件页面——
  清理、AI 数据、软件、优化、分析、状态、菜单栏,每个标签上的内容都不一样
- **七个专属页面**:`#/clean`、`#/ai`、`#/apps`、`#/optimize`、`#/analyze`、`#/status`、`#/menubar`,
  每页有自己的星球/视觉、诗句、能力清单与返回入口,可从阅览器直达、也可分享链接
- **3D 太阳系**:一块 WebGL 画布,五颗行星沿轨道运行,
  点击 / 悬停可切换右侧详情;太阳居中对应"状态"
- 工具页的按钮指向原版 mole.fit 的对应功能页,不假装功能已在本地实现
- 行星表面是**运行时用 Canvas 程序化生成**的,仓库里没有任何图片素材
- 尊重 `prefers-reduced-motion`:开启"减弱动态效果"后轨道与自转会安静下来

## 技术栈

| 层 | 选型 |
| --- | --- |
| 构建 | Vite |
| 框架 | React 19 + TypeScript |
| 3D | three.js + @react-three/fiber + @react-three/drei |
| 样式 | 原生 CSS(设计令牌集中在 `src/styles.css` 顶部) |

## 本地运行

```bash
pnpm install
pnpm dev      # http://localhost:5173
pnpm build    # 类型检查 + 产物构建
pnpm preview  # 预览构建产物
```

在线演示(由 GitHub Pages 自动部署):<https://csic21.github.io/mole-fit-study/>

## 目录结构

```
src/
  components/
    Nav.tsx              # 顶部胶囊导航
    Hero.tsx             # 首屏排版
    FeatureViewer.tsx    # 功能阅览器:标签切换,每个标签一张软件页面还原
    ToolPage.tsx         # 工具专属页:#/clean、#/optimize …(直达、可分享)
    Craft.tsx            # 设计说明一节
    Footer.tsx           # 页脚(含免责声明)
    mocks/
      MockPages.tsx      # 六张页面还原:清理 / AI / 软件 / 优化 / 分析 / 状态
    tool/
      MenubarMock.tsx    # "菜单栏"页的常驻指标条示意
    viewer/
      FeatureOrb.tsx     # 阅览器/工具页里的"星球雕塑"(慢速自转、轻微浮动)
    solar/
      SolarSystem.tsx    # 太阳系区块(画布、星尘、太阳、镜头微视差)
      Planet.tsx         # 单颗行星(轨道、自转、悬停/选中)
      textures.ts        # 程序化星球贴图与光晕(阅览器与太阳系共用)
  data/site.ts           # 星体与功能数据(文案、诗句、按钮都在这)
  hooks/
    useHashRoute.ts      # 极简 hash 路由(#/ 首页、#/clean… 工具页)
    useReducedMotion.ts
  styles.css             # 设计令牌 + 全部样式
```

想调整星球、文案、诗句或按钮指向,只改 `src/data/site.ts` 即可。

## 许可证

代码以 [MIT](./LICENSE) 协议开源。站点中出现的 "Mole" 名称及
mole.fit 的设计归其所有者所有;若有任何侵权疑虑,请提 issue,我们会立即处理。
