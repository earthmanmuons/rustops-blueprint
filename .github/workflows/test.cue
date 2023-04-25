package workflows

test: {
	name: "test"

	on: {
		pull_request: branches: [
			"main",
		]
		push: branches: [
			"main",
			"staging",
			"trying",
		]
	}

	concurrency: {
		group:                "${{ github.workflow }}-${{ github.head_ref || github.run_id }}"
		"cancel-in-progress": true
	}

	env: {
		CARGO_INCREMENTAL: 0
		CARGO_TERM_COLOR:  "always"
		RUST_BACKTRACE:    1
		RUSTFLAGS:         "-D warnings"
	}

	jobs: {
		required: {
			name:      "linux / stable"
			"runs-on": "ubuntu-latest"
			steps: [{
				name: "Checkout source code"
				uses: "actions/checkout@v3"
			}, {
				name: "Install stable Rust toolchain"
				uses: "dtolnay/rust-toolchain@stable"
			}, {
				name: "Install cargo-nextest"
				uses: "taiki-e/install-action@7522ae03ca435a0ad1001ca93d6cd7cb8e81bd2f"
				with: tool: "cargo-nextest"
			}, {
				name: "Cache dependencies"
				uses: "Swatinem/rust-cache@6fd3edff6979b79f87531400ad694fb7f2c84b1f"
			}, {
				name: "Compile tests"
				run:  "cargo test --locked --no-run"
			}, {
				name: "Run tests"
				run:  "cargo nextest run --locked"
			}]
		}

		workflow_status: {
			name:      "test workflow status"
			if:        "always()"
			"runs-on": "ubuntu-latest"
			needs: [
				"required",
			]
			steps: [{
				name: "Check `linux / stable` job status"
				run: """
					[[ \"${{ needs.required.result }}\" = \"success\" ]] && exit 0 || exit 1

					"""
			}]
		}
	}
}
