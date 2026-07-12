# moon_mutest

`moon_mutest` 是 MoonBit 项目的变异测试工具。它把小型代码改动应用到临时
workspace，再运行 `moon check` 和 `moon test`，用结果判断测试是否真的能发现
代码被改坏。

它关注的不是“测试有没有运行”，而是“断言是否足够强”。例如把 `==` 改成 `!=`、
把 `+` 改成 `-` 后测试仍通过，说明这个 mutant 逃逸，对应代码可能缺少精确断言或
边界用例。

- GitHub: <https://github.com/Magic486/moon_mutest>
- Gitlink: <https://www.gitlink.org.cn/Magic486/moon_mutest>

## 安装

库 API 可以从 mooncakes.io 安装：

```bash
moon add Magic486/moon_mutest@0.1.7
```

CLI 目前随源码仓库提供，需要在本仓库根目录执行：

```bash
moon run --target js cmd/main -- scan "a == b && true"
```

需要 Node.js 和可用的 `moon` 命令。CLI 会在临时目录运行，默认不会修改目标项目。

发布包的下游使用示例位于 `examples/consumer_workspace`，可在发布后验证：

```bash
moon -C examples/consumer_workspace test
```

## 最快用法

先从一个很小的范围开始：

```bash
moon run --target js cmd/main -- run path/to/workspace --max-mutants 10 --first 10
```

对全部生产源码运行时，工具默认：

1. 跳过 `*_test.mbt`、生成文件和 `_build`。
2. 复制目标 workspace 到临时目录。
3. 先执行基线 `moon check` 和 `moon test`。
4. 逐个应用 mutation 并汇总 `killed`、`survived`、`compile-error`、`timeout`、`skipped`、`equivalent`。

默认命令可以用 `--check-command` 与 `--test-command` 覆盖。

## 增量变异测试

对日常开发和 PR，推荐只测相对 Git 参考点发生变化的生产源码：

```bash
moon run --target js cmd/main -- run . \
  --changed-since origin/master \
  --max-mutants 30 \
  --first 10
```

`--changed-since REF` 先以 `git merge-base REF HEAD` 找到共同基线，再使用
`git diff --relative --name-only --diff-filter=ACMR BASE --` 获取
新增、复制、修改和重命名后的文件，并包含当前未提交修改。删除文件会被忽略。
报告中的 `changed-since`、`git-changed-files` 和 `incremental-files` 会显示实际范围。
使用该参数时，目标 workspace 必须位于可读取参考点的 Git 仓库中。

本地快速检查上一提交以来的改动：

```bash
moon run --target js cmd/main -- run . --changed-since HEAD~1 --max-mutants 20
```

在 CI 中，先确保 Git 历史包含参考分支；GitHub Actions 可以使用
`actions/checkout` 的 `fetch-depth: 0`，然后传入 `origin/master`。命令会以目标
workspace 作为相对路径根，因此嵌套的 MoonBit workspace 也能正确匹配 Git 文件。

也可以写入 workspace 根目录的 `moon_mutest.json`：

```json
{
  "changed_since": "origin/master",
  "max_mutants": 30,
  "first": 10,
  "fail_under": 80,
  "max_survived": 0
}
```

命令行参数优先于配置文件。未指定 `--config` 时，会自动读取
`workspace/moon_mutest.json`。

已人工确认的等价 mutant 可以在配置中注明 id 和原因。它会出现在报告中，但不影响
mutation score：

```json
{
  "equivalent": [
    { "id": 12, "reason": "该分支在当前域模型中与原逻辑等价" }
  ]
}
```

对于整行都不应生成 mutation 的生成代码或兼容代码，可在源码行末写
`// mutest:ignore`。这是一项显式抑制，不应被用来掩盖 escaped mutant。

## 质量门禁

将变异测试接入 CI 时，使用质量门禁让不达标的 run 返回非零退出码：

```bash
moon run --target js cmd/main -- run . \
  --changed-since origin/master \
  --fail-under 80 \
  --max-survived 0 \
  --max-compile-error 0 \
  --max-timeout 0 \
  --max-skipped 0
```

`--strict-gate` 是一组保守默认值：score 至少 90，且不允许 survived、
compile-error、timeout 或 skipped。

仓库内有两个可复现示例：

```bash
# 强断言：预期 killed=1、score=100%、质量门禁通过
moon run --target js cmd/main -- run examples/quality_gate_workspace \
  --max-mutants 1 --first 1 --fail-under 100 --max-survived 0 --max-skipped 0

# 弱断言：预期 survived=1、risk=high，并给出补测建议
moon run --target js cmd/main -- run examples/weak_test_workspace \
  --max-mutants 1 --first 1
```

## 报告

默认文本报告适合终端与 CI 日志。还支持：

```bash
# 供 CI 机器消费
moon run --target js cmd/main -- run . --format json --max-mutants 20

# 供代码评审或归档阅读
moon run --target js cmd/main -- run . --format markdown --max-mutants 20 > mutest-report.md

# 可离线打开的总览、文件风险排序与 survived 诊断
moon run --target js cmd/main -- run . --format html --max-mutants 20 > mutest-report.html
```

报告会按文件排序风险，并针对 survived mutant 给出建议。例如数值变异逃逸时会提示
补充精确数值断言和边界值测试。

## 常用参数

| 参数 | 用途 |
| --- | --- |
| `--profile basic\|boundary\|experimental` | 选择变异规则集。 |
| `--changed-since REF` | 只测相对 Git 参考点发生变化的生产文件。 |
| `--max-mutants N` / `--first N` | 限制规划或实际执行数量。 |
| `--id-start A --id-end B` | 执行半开区间 `[A, B)` 的 mutant id。 |
| `--include-tests` | 也把测试文件作为 mutation 目标。 |
| `--include-generated` | 包含生成的 MoonBit 文件。 |
| `--keep-temp` / `--temp-dir PATH` | 保留或指定临时 workspace，便于排障。 |
| `--no-fail-fast` | 一个 mutant 执行全部命令，而不是在首次有效信号后停止。 |
| `--format text\|markdown\|json\|html` | 选择报告格式。 |
| `--fail-under` 与 `--max-*` | 启用质量门禁。 |

## 作为库使用

```mbt check
///|
test {
  let manifest = @moon_mutest.manifest("a == b && true", file="demo.mbt")
  inspect(manifest.summary.candidate_count, content="3")
}
```

根包还提供扫描、规则过滤、项目计划、批次/分片选择、报告和质量门禁 API；详情可查看
生成的 API 文档或 [repository layout](docs/repository_layout.md)。

## 开发与 CI

提交前运行：

```bash
moon fmt
moon info
moon check --target all
moon test --target all
git diff --exit-code
```

GitHub Actions 位于 `.github/workflows/ci.yml`，覆盖 `moon check`、`moon test`、
`moon fmt`、`moon info`、CLI 示例、质量门禁和 HTML 报告。Gitlink 代码流水线可使用
仓库根目录的 `Jenkinsfile`。

当前 MoonBit 工具链若不支持 `moon fmt --deny-warn` 或 `moon info --deny-warn`，CI 会
自动使用对应的最新可用命令，再通过 `git diff --exit-code` 验证格式与接口文件没有未提交改动。

## 边界与许可证

- 当前 CLI 使用 JS/Node 后端执行真实 workspace；扫描与规划库支持 MoonBit 的常规后端。
- 变异测试会增加 CI 时间，建议 PR 使用 `--changed-since` 与 `--first`，全量扫描放到 nightly。
- Apache-2.0，见 [LICENSE](LICENSE)。
