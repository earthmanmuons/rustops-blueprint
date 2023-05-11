package workflows

rust: _#useMergeQueue & {
	name: "rust"

	env: {
		CARGO_INCREMENTAL: 0
		CARGO_TERM_COLOR:  "always"
		RUST_BACKTRACE:    1
		RUSTFLAGS:         "-D warnings"
	}

	jobs: {
		changes: _#detectFileChanges

		check: {
			name: "check"
			needs: ["changes"]
			"runs-on": defaultRunner
			if:        "needs.changes.outputs.rust == 'true'"
			steps: [
				_#checkoutCode,
				_#installRust,
				_#cacheRust,
				_#cargoCheck,
			]
		}

		format: {
			name: "format"
			needs: ["changes"]
			"runs-on": defaultRunner
			if:        "github.event_name == 'pull_request' && needs.changes.outputs.rust == 'true'"
			steps: [
				_#checkoutCode,
				_#installRust & {with: components: "rustfmt"},
				_#cacheRust,
				{
					name: "Check formatting"
					run:  "cargo fmt --check"
				},
			]
		}

		lint: {
			name: "lint"
			needs: ["changes"]
			"runs-on": defaultRunner
			if:        "github.event_name == 'pull_request' && needs.changes.outputs.rust == 'true'"
			steps: [
				_#checkoutCode,
				_#installRust & {with: components: "clippy"},
				_#cacheRust,
				{
					name: "Check lints"
					run:  "cargo clippy --all-targets --all-features -- -D warnings"
				},
			]
		}

		test_stable: {
			name: "test / stable"
			needs: ["check", "format", "lint"]
			defaults: run: shell: "bash"
			strategy: {
				"fail-fast": false
				matrix: platform: [
					"macos-latest",
					"ubuntu-latest",
					"windows-latest",
				]
			}
			"runs-on": "${{ matrix.platform }}"
			if:        "always() && needs.changes.outputs.rust == 'true'"
			steps: [
				_#checkoutCode,
				_#installRust,
				_#cacheRust & {with: "shared-key": "stable-${{ matrix.platform }}"},
				for step in _testRust {step},
			]
		}

		// Minimum Supported Rust Version
		check_msrv: {
			name: "check / msrv"
			needs: ["check", "format", "lint"]
			"runs-on": defaultRunner
			if:        "always() && needs.changes.outputs.rust == 'true'"
			steps: [
				_#checkoutCode,
				{
					id:   "msrv"
					name: "Get MSRV from package metadata"
					run:  "awk -F '\"' '/rust-version/{ print \"version=\" $2 }' Cargo.toml >> $GITHUB_OUTPUT"
				},
				_#installRust & {with: toolchain:  "${{ steps.msrv.outputs.version }}"},
				_#cacheRust & {with: "shared-key": "msrv-\(defaultRunner)"},
				_#cargoCheck,
			]
		}

		merge_queue: needs: [
			"changes",
			"test_stable",
			"check_msrv",
		]
	}
}
