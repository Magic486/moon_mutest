pipeline {
  agent any

  stages {
    stage('Install MoonBit') {
      steps {
        sh '''
          curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash
          export PATH="$HOME/.moon/bin:$PATH"
          moon version --all
          moon update
        '''
      }
    }

    stage('Check') {
      steps {
        sh '''
          export PATH="$HOME/.moon/bin:$PATH"
          moon check --target all
        '''
      }
    }

    stage('Test') {
      steps {
        sh '''
          export PATH="$HOME/.moon/bin:$PATH"
          moon test --target all
        '''
      }
    }

    stage('Fmt Info') {
      steps {
        sh '''
          export PATH="$HOME/.moon/bin:$PATH"

          if moon fmt --help | grep -q -- '--deny-warn'; then
            moon fmt --deny-warn
          else
            moon fmt
            git diff --exit-code
          fi

          if moon info --help | grep -q -- '--deny-warn'; then
            moon info --deny-warn
          else
            moon info
          fi

          git diff --exit-code
        '''
      }
    }

    stage('CLI') {
      steps {
        sh '''
          export PATH="$HOME/.moon/bin:$PATH"

          moon run --target js cmd/main -- scan "a == b && true"

          moon -C examples/consumer_workspace update
          moon -C examples/consumer_workspace info
          moon -C examples/consumer_workspace fmt
          git diff --exit-code
          moon -C examples/consumer_workspace test

          if git rev-parse --verify HEAD~1 >/dev/null 2>&1; then
            moon run --target js cmd/main -- run . \
              --changed-since HEAD~1 \
              --max-mutants 1 \
              --first 1
          fi

          moon run --target js cmd/main -- run examples/quality_gate_workspace \
            --max-mutants 1 \
            --first 1 \
            --fail-under 100 \
            --max-survived 0 \
            --max-skipped 0

          moon run --target js cmd/main -- run examples/weak_test_workspace \
            --format html \
            --max-mutants 1 \
            --first 1 > mutest-report.html

          test -s mutest-report.html
          grep -Fq "File Risk Ranking" mutest-report.html

          moon coverage analyze > coverage.txt
        '''
      }
    }
  }
}
