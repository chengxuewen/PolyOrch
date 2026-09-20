# PolyOrch

[English](./README.md) | **简体中文**

> **A scalable build orchestrator for polyglot monorepos.**
>
> *Adapter-based integration for heterogeneous build systems, environments, and package managers.*
>
> **面向多语言 monorepo 的可扩展构建编排器。**

PolyOrch 面向多语言 monorepo：多种语言、多套构建系统、一张构建图。它通过适配器完成编排，让每个
子项目继续使用自己的原生工具链，同时让整个仓库获得统一的构建、运行、调试与内省入口。

## 状态

**本仓库不含任何源码。** 它是文档优先的：当前阶段的交付物是 v1.0 规格说明，以及将来用于构建它的
AI agent 工具链。这里没有 `src/`、没有构建入口、没有测试套件 —— 不必寻找。

| | |
|---|---|
| 阶段 | 设计已落地 —— 白皮书 v1.0、架构设计基线、模块参考、12 个项目画像 |
| 计划技术栈 | Lua，以 Xmake addon 形式分发（Xmake 作引擎，Pixi 管环境） |
| 源码树 | 尚未加入 |

当下真正的门禁是 `.agents/memorys/conventions.md` 里的 shell 检查（C0–C5）；
没有可运行的构建或测试系统。

## 仓库结构

```text
docs/          规格说明 —— 从 docs/README.md 开始
  whitepaper.md      冻结的 v1.0 记录（历史快照，非工作权威）
  derived/           工作用产品面：adapters、cli、environment、naming、competitive-analysis、outline
  architecture.md    设计基线：不变式、分层、数据流、未决项
  modules/           内部实现参考
  reference/         外部来源的 12 个相关项目画像
.agents/
  rules/         恒常约束
  memorys/       易变事实（status / conventions / decisions / pitfalls）
  skills/        agent 技能，含 58 个 vendored Xmake 技能
.opencode/     opencode 配置
scripts/       空 —— 计划中的门禁运行器
AGENTS.md      agent 知识库，每轮加载
SKILL.md       技能登记表
```

## 从哪里开始

| 你是 | 读 |
|---|---|
| 初次接触本项目 | [`docs/README.md`](./docs/README.md) —— 文档枢纽 |
| 评估设计 | [`docs/whitepaper.md`](./docs/whitepaper.md)，然后 [`docs/architecture.md`](./docs/architecture.md) |
| 在此工作的 agent | [`AGENTS.md`](./AGENTS.md) —— 知识库 |
| 找某个技能 | [`SKILL.md`](./SKILL.md) —— 技能登记表 |

## 许可证

Apache-2.0 —— 见 [`LICENSE`](./LICENSE)。

`.agents/skills/` 下的 58 个 `xmake-*` / `xrepo-*` 技能是同一许可证下的第三方内容，vendored 自
`xmake-io/xmake-skills`；其来源、pinned commit 与修改声明记录在
[`.agents/skills/XMAKE-ATTRIBUTION.md`](./.agents/skills/XMAKE-ATTRIBUTION.md)。

---

> 本文件是 [`README.md`](./README.md) 的中文镜像，供人阅读。两者不一致时，以英文版为准。
> 它是本项目里唯一被允许包含中文正文的产物 —— 见 `.agents/memorys/conventions.md` C4 第 3 条。
