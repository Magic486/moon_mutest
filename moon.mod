// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
//
// To add a dependency, run this command in your terminal:
//   moon add moonbitlang/x
//
// Or manually declare it in `import`, for example:
// import {
//   "moonbitlang/x@0.4.6",
// }

name = "Magic486/moon_mutest"

version = "0.1.1"

readme = "README.mbt.md"

repository = "https://github.com/Magic486/moon_mutest"

license = "Apache-2.0"

keywords = [ "mutation-testing", "testing", "quality", "cli" ]

description = "Mutation testing toolkit for MoonBit projects"

import {
  "moonbitlang/x@0.4.45",
}

options(
  exclude: [ ".github", "docs", "examples", "tests" ],
)
