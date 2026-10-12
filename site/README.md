# 栖理产品介绍页

React + TypeScript + Vite。品牌为栖理 / Qili，展示原生 App 当前已实现的五项工具。
首屏的界面预览用 CSS 按原生深色工作台的样式模拟绘制(见 `src/components/AppWindow.tsx`,
示例数据);网页没有本机扫描、清理、卸载或维护操作,也没有未实现的 AI / 菜单栏功能宣传。

## 运行

```bash
pnpm install --frozen-lockfile
pnpm dev
pnpm build
pnpm lint
```

GitHub Pages 的子路径通过 `PAGES_BASE=/qili/` 注入。
`src/data/site.ts` 集中维护功能说明、下载地址和素材地址；功能链接兼容 `#/clean`、
`#/apps`、`#/optimize`、`#/analyze` 与 `#/status`，可直接分享。

图标来自 `../Assets/Branding/QiliLogo.png`，运行仓库根目录的
`bash scripts/generate_icons.sh` 可同步网页与原生资源。

源码与下载指向本仓库；来源说明见 [PROVENANCE](../docs/PROVENANCE.md)。
代码使用 [MIT](LICENSE)，第三方依赖保留各自许可证。
