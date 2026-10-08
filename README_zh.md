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

**交付物是 CMake 辅助面及其测试套件** —— `cmake/` 模块（pixi 环境面、rust 面、node 面、python
面），`tests/`（离线单元 + fixture e2e + 生成器矩阵），`examples/`。文档仍是规格层；白皮书是
冻结的 v1.0 记录（见 `.agents/memorys/decisions.md` 的 D16）。

| | |
|---|---|
| 阶段 | 实施进行中 —— CMake 辅助面（pixi 环境、rust、node、python 面）、fixture 测试套件、本地生成器矩阵；D16 取代旧的 Lua/Xmake-addon 交付形态 |
| 技术栈 | CMake 辅助面；Pixi 环境；xmake = 参考语料 + 包管理来源（vcpkg · Conan 经 Xrepo） |
| 测试 | `bash tests/run.sh`（离线）· `POLYORCH_TEST_E2E=1 bash tests/run.sh` · `bash tests/matrix.sh` |

约束性门禁是 `.agents/memorys/conventions.md` 的 shell 检查（C0–C6），由 `scripts/gate.sh` 一并执行；
测试体系即 `tests/` 的 cmake 用例套件。

## 仓库结构

```text
docs/          规格说明 —— 从 docs/README.md 开始
  tutorials.md       手把手学习路径（入门、Rust 构建、绑定、宿主嵌入）
  whitepaper.md      冻结的 v1.0 记录（历史快照，非工作权威）
  derived/           工作用产品面：adapters、cli、environment、naming、competitive-analysis、outline
  architecture.md    设计基线：不变式、分层、数据流、未决项
  modules/           内部实现参考
  reference/         外部来源的 12 个相关项目画像
.agents/
  rules/         恒常约束
  memorys/       易变事实（status / conventions / decisions / pitfalls）
  skills/        agent 技能（58 个 vendored Xmake 技能已移入 docs/reference/xmake-skills/）
.opencode/     opencode 配置
scripts/       激活三件套（pixi.sh/.bat/.ps1）+ 门禁运行器（gate.sh/ctest.sh）
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

`docs/reference/xmake-skills/` 下的 58 个 `xmake-*` / `xrepo-*` 技能是同一许可证下的第三方内容（2026-10-08 起退出技能加载器，仅作参考语料），vendored 自
`xmake-io/xmake-skills`；其来源、pinned commit 与修改声明记录在
[`docs/reference/xmake-skills/XMAKE-ATTRIBUTION.md`](./docs/reference/xmake-skills/XMAKE-ATTRIBUTION.md)。

---

> 本文件是 [`README.md`](./README.md) 的中文镜像，供人阅读。两者不一致时，以英文版为准。
> 它是本项目里唯一被允许包含中文正文的产物 —— 见 `.agents/memorys/conventions.md` C4 第 3 条。
