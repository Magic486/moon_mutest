# moon_mutest

`moon_mutest` 是一个面向 MoonBit 项目的变异测试工具包。它会扫描
MoonBit 源码，生成保守的变异点，把每个变异点应用到真实项目的临时副本中，
再执行 `moon check` / `moon test`，最后汇总每个 mutant 是被测试杀死、
逃逸、编译失败、超时还是被跳过。

这个项目的目标不是替代 `moon test`，而是回答一个更尖锐的问题：

> 你的测试不仅会运行，还真的能发现代码被悄悄改坏了吗？

项目同时提供两层能力：

- 一个可复用的 MoonBit 库，用于扫描、规划、过滤、生成报告和质量门禁。
- 一个 JS/Node 后端 CLI，用于对真实 MoonBit workspace 自动执行变异测试。

仓库地址：

- GitHub: <https://github.com/Magic486/moon_mutest>
- Gitlink: <https://www.gitlink.org.cn/Magic486/moon_mutest>

## 项目背景

普通单元测试通常只告诉我们“当前测试是否通过”。覆盖率工具可以告诉我们
“哪些行被执行过”。但它们都不一定能证明测试具有足够的断言能力。

变异测试会主动制造小型缺陷，例如：

- 把 `==` 改成 `!=`
- 把 `&&` 改成 `||`
- 把 `true` 改成 `false`
- 把 `<` 改成 `<=`
- 把 `+` 改成 `-`

如果测试失败，说明这个变异被“杀死”，测试对这类缺陷有感知能力。如果测试仍然
通过，说明该 mutant “逃逸”，对应位置可能缺少断言、边界用例或业务约束测试。

MoonBit 生态正在快速发展，项目会越来越依赖自动化测试和 CI。`moon_mutest`
尝试补上 MoonBit 质量基础设施中“测试强度评估”这一块。

## 当前能力

当前版本已经实现了从源码扫描到真实 workspace 自动运行的闭环：

- 扫描 MoonBit 源码并生成变异候选点。
- 跳过字符串、字符字面量、行注释和块注释，避免明显误报。
- 支持基础规则集和边界规则集。
- 生成文本、JSON 和 Markdown 报告。
- 为多文件项目生成全局 mutant id。
- 支持按 mutant 数量、id 范围、分片和批次规划执行。
- 支持 patch preview 和可逆文本编辑。
- 支持基线检查，只有原项目先通过 `moon check` / `moon test` 才继续跑 mutants。
- 支持筛选生产文件、测试文件和生成文件。
- 支持 Bash / PowerShell dry-run 脚本生成。
- 支持 JS/Node workspace runner：
  - 读取真实 MoonBit workspace 文件。
  - 复制临时 workspace。
  - 逐个应用 mutation。
  - 执行 `moon check` / `moon test` 或自定义命令。
  - 恢复被修改文件。
  - 汇总真实运行结果。
- 支持质量门禁：
  - mutation score
  - survived mutants
  - compile errors
  - timeouts
  - skipped mutants

## 快速开始

先确认已经安装 MoonBit 工具链，并且命令行可以使用 `moon`。

克隆仓库后，在项目根目录运行：

```bash
moon check --warn-list +73
moon test --warn-list +73
```

扫描一段源码：

```bash
moon run --target js cmd/main -- scan "a == b && true"
```

示例输出：

```text
Mutation candidates for <memory>
total: 3
boolean: 1
equality: 1
relational: 0
arithmetic: 0
logical: 1
numeric: 0

#0 <memory>:1:3 eq-to-ne == -> != | a == b && true
#1 <memory>:1:8 and-to-or && -> || | a == b && true
#2 <memory>:1:11 true-to-false true -> false | a == b && true
```

对真实 MoonBit 项目运行变异测试：

```bash
moon run --target js cmd/main -- run . --max-mutants 10 --first 10
```

如果你想先保守地试跑，可以限制 mutant 数量：

```bash
moon run --target js cmd/main -- run path/to/workspace --max-mutants 5 --first 5
```

## CLI 用法

### scan

`scan` 用来扫描一段源码字符串，不会访问真实项目文件。它适合快速查看某个表达式
会生成哪些 mutation。

```bash
moon run --target js cmd/main -- scan "score >= limit && enabled"
```

使用边界规则集：

```bash
moon run --target js cmd/main -- scan --profile boundary "let n = 0"
```

输出 JSON，方便 CI 或其他工具消费：

```bash
moon run --target js cmd/main -- scan --json --profile boundary "let n = 1"
```

### run

`run` 会读取真实 MoonBit workspace，复制一份临时目录，然后在临时目录中执行
变异测试。默认命令是：

```bash
moon check --warn-list +73
moon test --warn-list +73
```

常用参数：

- `--profile basic|boundary|experimental`：选择规则集。
- `--format text|markdown|json`：选择报告格式。
- `--max-mutants N`：规划阶段最多保留 N 个 mutants。
- `--first N`：只执行前 N 个 mutants。
- `--id-start A --id-end B`：执行 `[A, B)` 范围内的 mutant id。
- `--include-tests`：把 `*_test.mbt` / `*_wbtest.mbt` 也作为变异目标。
- `--include-generated`：包含生成文件。
- `--keep-temp`：保留临时 workspace，方便调试。
- `--no-fail-fast`：对同一个 mutant 执行所有配置命令。
- `--temp-dir PATH`：指定临时 workspace 路径。
- `--check-command "..."`：自定义 check 阶段命令。
- `--test-command "..."`：自定义 test 阶段命令。

示例：

```bash
moon run --target js cmd/main -- run . \
  --profile boundary \
  --format markdown \
  --max-mutants 30 \
  --first 10
```

输出 JSON：

```bash
moon run --target js cmd/main -- run . --format json --max-mutants 10
```

保留临时目录：

```bash
moon run --target js cmd/main -- run . --keep-temp --temp-dir _build/mutest-debug
```

## 结果含义

每个 mutant 会被归类为以下状态之一：

- `Killed`：测试阶段失败，说明测试发现了这个变异。
- `Survived`：所有命令通过，说明这个变异逃逸，测试可能不够强。
- `CompileError`：check/build 阶段失败，变异导致代码无法编译。
- `Timeout`：命令超过时间预算。
- `Skipped`：runner 没有得到可用执行结果。

通常最需要关注的是 `Survived`。它们往往意味着：

- 缺少关键断言。
- 没有覆盖边界条件。
- 测试只检查了流程，没有检查结果。
- 业务逻辑中存在等价实现，需要人工确认。

## 支持的变异规则

默认 `basic` 规则集包含：

- boolean：`true <-> false`
- equality：`== <-> !=`
- relational：`<`, `<=`, `>`, `>=` 的边界替换
- arithmetic：`+`, `-`, `*`, `/`
- logical：`&& <-> ||`

`boundary` 规则集额外包含数字边界变异：

- `0 -> 1`
- `1 -> 0`
- `-1 -> 0`

规则设计偏保守，优先保证输出可解释、可复现、便于调试。后续可以继续扩展到模式匹配、
函数调用、集合操作、错误处理分支等更高阶的 MoonBit 语义规则。

## 库 API 示例

除了 CLI，`moon_mutest` 也可以作为 MoonBit 库使用。

```mbt check
///|
test {
  let manifest = @moon_mutest.manifest("a + b == c && false", file="demo.mbt")
  inspect(manifest.summary.candidate_count, content="4")
  inspect(manifest.candidates[0].rule.label, content="add-to-sub")

  let mutants = @moon_mutest.generate_mutants("a + b == c", file="demo.mbt")
  inspect(mutants[0].source, content="a - b == c")
}
```

生成 JSON manifest：

```mbt check
///|
test {
  let text = @moon_mutest.format_manifest_json("a == b", file="demo.mbt")
  assert_true(text.contains("\"candidate_count\": 1"))
  assert_true(text.contains("\"eq-to-ne\""))
}
```

多文件项目规划：

```mbt check
///|
test {
  let plan = @moon_mutest.plan_project([
    @moon_mutest.source_file("src/a.mbt", "a == b"),
    @moon_mutest.source_file("src/b.mbt", "x + y && false"),
  ])
  inspect(plan.file_count, content="2")
  inspect(plan.mutation_count, content="4")
  inspect(plan.mutations[0].global_id, content="0")
}
```

生成 patch preview：

```mbt check
///|
test {
  let source = "let ok = a == b"
  let candidate = @moon_mutest.discover(source, file="a.mbt")[0]
  let preview = @moon_mutest.preview_candidate_patch(source, candidate)
  assert_true(preview is Some(_))
}
```

## 真实 workspace runner

真实项目执行是本项目最关键的部分。`runner/` 子包和 `cmd/main/` CLI 使用 JS target，
原因是它们需要 Node 环境提供文件系统和进程执行能力。

执行流程如下：

1. 读取 workspace 中符合条件的 `.mbt` 文件。
2. 按配置排除 `_build/`、生成文件、测试文件等目标。
3. 为所有文件生成 mutation plan。
4. 复制 workspace 到临时目录。
5. 在临时目录执行 baseline 命令。
6. baseline 通过后，按选择策略逐个应用 mutant。
7. 对每个 mutant 执行 check/test 命令。
8. 根据命令退出码、阶段和超时情况分类结果。
9. 恢复被修改文件。
10. 删除临时目录，除非指定 `--keep-temp`。
11. 输出文本、Markdown 或 JSON 报告。

这个设计避免直接修改用户项目，也让每次运行都更容易复现。

## CI 规划能力

`moon_mutest` 不只关注本地一次性运行，也提供适合 CI 的规划 API。

```mbt check
///|
test {
  let config = @moon_mutest.MutestConfig::default()
  let plan = @moon_mutest.build_execution_plan(
    [
      @moon_mutest.source_file("src/a.mbt", "a == b && false"),
      @moon_mutest.source_file("src/b.mbt", "x + y"),
    ],
    config,
  )

  let selected = @moon_mutest.select_executions(
    plan,
    Shard(shard_index=1, shard_count=2),
  )
  inspect(selected.length(), content="2")

  let batches = @moon_mutest.build_selected_batch_plan(
    plan,
    FirstMutants(2),
    OneMutantPerBatch,
  )
  inspect(batches.batch_count, content="2")

  let script = @moon_mutest.generate_selected_runner_script(
    plan,
    FirstMutants(1),
    BashDialect,
  )
  assert_true(script.content.contains("moon-mutest baseline"))
}
```

这部分能力可以用于：

- 把大型项目的 mutation run 拆成多个 CI 分片。
- 只跑本次变更附近的 mutant。
- 为 nightly job 生成批处理计划。
- 给质量门禁提供稳定输入。

## Workspace 文件选择

默认只选择生产源码，跳过测试文件和生成文件。需要时可以显式打开这些选项。

```mbt check
///|
test {
  let files = [
    @moon_mutest.source_file("src/lib.mbt", "a == b"),
    @moon_mutest.source_file("src/lib_test.mbt", "test {}"),
    @moon_mutest.source_file("_build/gen/out.mbt", "let x = 1"),
  ]
  let selected = @moon_mutest.select_workspace_files(
    files,
    @moon_mutest.WorkspaceFileSpec::moonbit_default(),
  )
  inspect(selected.length(), content="1")
  inspect(selected[0].path, content="src/lib.mbt")
}
```

## 质量门禁

项目级报告可以接入质量门禁，用于 CI 中判断是否允许合并。

```mbt check
///|
test {
  let plan = @moon_mutest.plan_project([
    @moon_mutest.source_file("src/a.mbt", "a == b"),
  ])
  let report = @moon_mutest.summarize_project_run(plan, [
    @moon_mutest.project_result(plan.mutations[0], Killed),
  ])
  let gate = @moon_mutest.evaluate_quality_gate(
    report,
    @moon_mutest.QualityGate::default(),
  )
  inspect(@moon_mutest.quality_gate_status_label(gate.status), content="passed")
}
```

质量门禁可以围绕这些指标设置：

- 最低 mutation score。
- 最多允许多少 survived mutants。
- 是否允许 compile errors。
- 是否允许 timeout。
- 是否允许 skipped mutants。

## 仓库结构

根包是对外 facade，主要 re-export 各功能子包的公开 API。核心代码按职责拆分：

- `core/`：扫描器、规则、过滤和 mutant 生成。
- `io/`：manifest、JSON 和文本输出。
- `plan/`：项目规划、workspace 文件选择。
- `run/`：patch、执行计划、项目报告、baseline、脚本和质量门禁。
- `runner/`：JS/Node workspace 复制、mutation 应用、进程执行和真实结果汇总。
- `cmd/main/`：命令行入口。
- `tests/`：黑盒测试，覆盖根包公开 API。
- `docs/`：项目说明、比赛材料和仓库结构文档。

更详细的结构说明见 `docs/repository_layout.md`。

## 开发与验证

推荐在提交前运行：

```bash
moon check --warn-list +73
moon check --target js --warn-list +73
moon build
moon test --warn-list +73
moon test --target js --warn-list +73
moon fmt
moon info
```

根包和大部分规划、报告逻辑保持平台无关，方便测试。真实 workspace runner 依赖
JS target，因为它需要调用 Node 的文件系统和子进程能力。

## 比赛契合点

本项目面向 MoonBit 国产开源生态建设，重点补充测试质量基础设施。它和现有
`moon test`、`moon coverage` 的关系是互补的：

- `moon test` 检查测试是否通过。
- coverage 检查代码是否被执行。
- `moon_mutest` 检查测试是否能发现被注入的语义缺陷。

对于 CCF 开源创新大赛 / MoonBit 生态方向，这个项目的价值在于：

- 主题明确，直接服务 MoonBit 工具链和开发者体验。
- 技术路线有新意，不是简单包装已有命令。
- 已经形成库、CLI、真实 runner、报告和质量门禁的完整闭环。
- 可以继续扩展规则、CI 集成、增量运行和可视化报告。

## 当前边界

当前版本仍然保持 MVP 取向，规则以源码级保守替换为主。它不会尝试理解所有
MoonBit 语义，也不会保证每个 mutant 都一定有业务意义。

已知边界包括：

- 复杂语法结构的语义级 mutation 仍需继续扩展。
- 等价 mutant 需要通过规则优化和人工判断逐步减少。
- 大型项目运行时间需要依赖分片、选择策略和 CI 缓存优化。
- Windows、macOS、Linux 的进程行为还可以继续增加端到端覆盖。

这些边界不会影响当前工具用于发现测试薄弱点，但后续仍有很明确的演进空间。

## License

Apache-2.0.
