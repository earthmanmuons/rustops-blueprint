package workflows

githubActions: _#borsWorkflow & {
	name: "github-actions"

	on: push: branches: borsBranches

	env: CARGO_TERM_COLOR: "always"

	jobs: {
		changes: _#detectFileChanges

		cueVet: {
			name: "cue / vet"
			needs: ["changes"]
			"runs-on": defaultRunner
			if:        "${{ needs.changes.outputs.github-actions == 'true' }}"
			steps: [
				_#checkoutCode,
				_#installCue,
				{
					name:                "Validate CUE files"
					"working-directory": ".github/cue"
					run:                 "cue vet -c"
				},
			]
		}

		cueFormat: {
			name: "cue / format"
			needs: ["cueVet"]
			"runs-on": defaultRunner
			steps: [
				_#checkoutCode,
				_#installCue,
				{
					name:                "Format CUE files"
					"working-directory": ".github/cue"
					run:                 "cue fmt --simplify"
				},
				{
					name: "Check if CUE files were reformatted"
					run: """
						if git diff --quiet HEAD --; then
						    echo "CUE files were already formatted; the working tree is clean."
						else
						    git diff --color --patch-with-stat HEAD --
						    echo "***"
						    echo "Error: CUE files are not formatted; the working tree is dirty."
						    echo "Run 'cargo xtask fixup.github-actions' locally to format the CUE files."
						    exit 1
						fi
						"""
				},
			]
		}

		cueSynced: {
			name: "cue / synced"
			needs: ["cueVet"]
			"runs-on": defaultRunner
			steps: [
				_#checkoutCode,
				_#installCue,
				{
					name:                "Regenerate YAML from CUE"
					"working-directory": ".github/cue"
					run:                 "cue cmd regen-ci-yaml"
				},
				{
					name: "Check if CUE and YAML are in sync"
					run: """
						if git diff --quiet HEAD --; then
						    echo "CUE and YAML files are in sync; the working tree is clean."
						else
						    git diff --color --patch-with-stat HEAD --
						    echo "***"
						    echo "Error: CUE and YAML files are out of sync; the working tree is dirty."
						    echo "Run 'cargo xtask fixup.github-actions' locally to regenerate the YAML from CUE."
						    exit 1
						fi
						"""
				},
			]
		}

		bors: needs: [
			"cueFormat",
			"cueSynced",
		]
	}
}
