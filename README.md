# actions-sbom-syft

A composite GitHub Action that generates a CISA-conformant Software Bill of
Materials (SBOM) with [Syft](https://github.com/anchore/syft), enriches it
with the CISA minimum-required metadata fields, and optionally signs it
with a GitHub Artifact Attestation, attaches it to a container image in
GHCR, uploads it to a GitHub Release, or embeds it into a built package
archive (npm, Maven, NuGet).

See [`doc/plan.md`](doc/plan.md) for the full specification this action was
built against, and [`.github/REVIEW_GUIDELINES.md`](.github/REVIEW_GUIDELINES.md)
for how changes to this repository are reviewed.

## Inputs

| Input                 | Required | Default                              | Description                                                                 |
| ---------------------- | -------- | ------------------------------------- | ----------------------------------------------------------------------------- |
| `target`               | no       | `.`                                    | Target directory, container image, or archive to scan.                       |
| `source-name`          | **yes**  | —                                      | Name of the component or software product.                                   |
| `source-version`       | no       | `` (empty)                             | Explicit version. If omitted, resolved from release-please or `git describe`. |
| `release-please-file`  | no       | `.release-please-manifest.json`        | Path to a release-please manifest for version resolution.                    |
| `author`               | no       | `${{ github.repository_owner }}`       | Author/creator recorded on the SBOM.                                         |
| `supplier`              | no       | `` (empty)                             | Component supplier/vendor organization name.                                  |
| `generation-context`   | no       | `post-build`                           | CISA lifecycle stage: `build`, `post-build`, `pre-build`, or `source`.       |
| `attest`               | no       | `true`                                 | Create a signed GitHub Artifact Attestation for the SBOM.                     |
| `attach-ghcr`          | no       | `false`                                | Attach the SBOM to an OCI image in GHCR via `cosign` (cosign must already be on `PATH`). |
| `attach-release`       | no       | `false`                                | Upload the SBOM as an asset on a GitHub Release.                              |
| `release-tag`          | no       | `` (empty)                             | Target release tag. Required if `attach-release` is `true`.                   |
| `package-type`         | no       | `none`                                 | Archive type to embed the SBOM into: `none`, `npm`, `maven`, `nuget`.         |
| `package-file-path`    | no       | `` (empty)                             | Path to the local archive file. Required if `package-type` is not `none`.     |

## Outputs

| Output                | Description                                                               |
| ----------------------- | --------------------------------------------------------------------------- |
| `sbom-path`             | Absolute path to the enriched CISA `sbom.json`.                            |
| `resolved-version`      | Final version string applied to the SBOM metadata.                        |
| `attestation-digest`    | `sha256:`-prefixed digest of the attested SBOM file (empty if `attest` is `false`). |

## Permissions

Grant your job the permissions the features you use need:

```yaml
permissions:
  contents: write # required for GitHub Release upload
  packages: write # required for GHCR push
  id-token: write # required for GitHub Sigstore Artifact Attestation
  attestations: write # required for GitHub Artifact Attestation write
```

## Usage

### Scenario A: Standalone CISA SBOM with automated release-please

```yaml
name: Security & Release Pipelines

on:
  push:
    branches: [main]

jobs:
  release:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      id-token: write
      attestations: write
    steps:
      - uses: actions/checkout@v7.0.1

      - name: Run Release-Please
        id: release
        uses: googleapis/release-please-action@v5.0.0
        with:
          release-type: node

      - name: Generate & Attest CISA SBOM
        uses: vln-devsecops/actions-sbom-syft@v1
        with:
          source-name: "my-microservice"
          release-please-file: ".release-please-manifest.json"
          author: "SecOps Team"
          supplier: "Acme Software Enterprise"
          generation-context: "post-build"
          attest: "true"
```

### Scenario B: Container build with GHCR attestation & OCI attachment

```yaml
jobs:
  build-container:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      packages: write
      id-token: write
      attestations: write
    steps:
      - uses: actions/checkout@v7.0.1

      - name: Log in to GHCR
        uses: docker/login-action@v4.6.0
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build and push Docker image
        run: |
          docker build -t ghcr.io/${{ github.repository }}:v1.2.0 .
          docker push ghcr.io/${{ github.repository }}:v1.2.0

      - name: Install cosign
        uses: sigstore/cosign-installer@v4.1.2

      - name: Generate SBOM and attach to GHCR
        uses: vln-devsecops/actions-sbom-syft@v1
        with:
          target: "ghcr.io/${{ github.repository }}:v1.2.0"
          source-name: "my-app-container"
          source-version: "1.2.0"
          attach-ghcr: "true"
          attest: "true"
```

### Scenario C: Embedded language package (Java / Maven JAR distribution)

```yaml
jobs:
  package-java:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      id-token: write
      attestations: write
    steps:
      - uses: actions/checkout@v7.0.1

      - name: Build Java package
        run: ./gradlew build

      - name: Generate SBOM and embed into JAR
        uses: vln-devsecops/actions-sbom-syft@v1
        with:
          source-name: "billing-api"
          source-version: "2.1.0"
          package-type: "maven"
          package-file-path: "build/libs/billing-api-2.1.0.jar"
          attest: "true"

      - name: Publish artifact
        run: ./gradlew publish
```

## Development

This repository was built test-first (BDD + TDD) as a stack of small pull
requests; see `.github/REVIEW_GUIDELINES.md` for the review bar each one was
held to.

```
.
├── action.yml                  # composite action wiring
├── scripts/                    # the action's shell implementation
│   ├── validate-target.sh
│   ├── resolve-version.sh
│   ├── enrich-cisa.sh
│   └── attach-package.sh
├── features/                   # Gherkin acceptance criteria (BDD)
├── tests/
│   ├── unit/                   # bats unit tests (TDD), one per script
│   ├── bdd/                    # bats acceptance tests, one per feature scenario
│   └── fixtures/
└── .github/workflows/
    ├── test-unit.yml           # shellcheck + shfmt + unit tests
    └── test-e2e.yml            # BDD acceptance tests
```

Run the full test suite locally (requires `bash`, `bats-core`, `jq`,
`shellcheck`, `shfmt`, `tar`, `zip`/`unzip`, and `git`):

```sh
shellcheck scripts/*.sh
shfmt -d scripts/*.sh
bats tests/unit/*.bats tests/bdd/*.bats
```
