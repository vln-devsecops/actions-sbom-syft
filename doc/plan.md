# Living Plan: CISA-Conformant SBOM GitHub Action

This document serves as an actionable, test-driven specification for building a composite GitHub Action derived from the architecture of vln-devsecops/actions-sca-syft-grype. The new action automates the generation, enrichment, attestation, and distribution of CISA-conformant Software Bill of Materials (SBOM) documents.

# System Architecture & Specification
The action encapsulates five sequential operational phases:
[ Input Resolution ] ──> [ Syft Generation ] ──> [ CISA Metadata Injection ] ──> [ Attestation ] ──> [ Opt-In Distribution ]
   (release-please)       (CycloneDX JSON)             (jq Post-Processor)         (GitHub Attest)     (GHCR / GHR / Packages)

## 1. Action Interface (action.yml)

 * Inputs:
   * target: Target directory, container image, or archive to scan (default: .).
   * source-name: Name of the component or software product (defaults to repository name).
   * source-version: Explicit version string. If omitted, triggers release-please auto-resolution.
   * release-please-file: Path to .release-please-manifest.json for version resolution (default: .release-please-manifest.json).
   * author: Author/Creator of the SBOM (default: ${{ github.repository_owner }}).
   * supplier: Component supplier or vendor organization name.
   * generation-context: Build lifecycle stage (build, post-build, pre-build, source). Default: post-build.
   * attest: Boolean flag to create a signed GitHub Artifact Attestation (default: ‘true’).
   * attach-ghcr: Boolean flag to push SBOM to GHCR using cosign (default: ‘false’).
   * attach-release: Boolean flag to upload SBOM as an asset to a GitHub Release (default: ‘false’).
   * release-tag: Target tag for GitHub Release attachment (required if attach-release is ‘true’).
   * package-type: Target package ecosystem for payload embedding (none, npm, maven, nuget). Default: none.
   * package-file-path: Target archive file to inject the SBOM into (e.g., dist/app.jar or pkg.tgz).
 * Outputs:
   * sbom-path: Absolute path to the generated CISA-compliant sbom.json.
   * resolved-version: Final version string applied to the SBOM metadata.
   * attestation-digest: Cryptographic digest of the signed attestation bundle (if enabled).
 
## 2. BDD Specifications (Gherkin Feature Files)

Place these feature files in features/ to drive implementation validation.

### Feature 1: CISA-Compliant Metadata Injection

```gherkin
Feature: CISA-Compliant Metadata Enrichment
  As a DevSecOps Engineer
  I want Syft SBOM outputs enriched with CISA minimum required fields
  So that downstream compliance tools validate our supply chain metadata.

  Scenario: Explicit Metadata Input
    Given a source path “.” containing a valid software project
    When the SBOM action runs with:
      | input              | value                     |
      | source-name        | core-payment-service      |
      | source-version     | 2.4.0                     |
      | author             | DevSecOps Team            |
      | supplier           | Acme Corp                 |
      | generation-context | post-build                |
    Then an SBOM file is generated at “sbom.json”
    And the JSON property “.metadata.component.name” equals “core-payment-service”
    And the JSON property “.metadata.component.version” equals “2.4.0”
    And the JSON array “.metadata.authors” contains an entry with name “DevSecOps Team”
    And the JSON property “.metadata.supplier.name” equals “Acme Corp”
    And the JSON array “.metadata.properties” contains a property “cisa:generationContext” with value “post-build”
```

### Feature 2: Release-Please Version Resolution

```gherkin
Feature: Automatic Version Extraction via Release-Please
  As a Release Manager
  I want the action to automatically infer component versions from release-please manifests
  So that I do not have to manually pass version parameters in CI/CD pipelines.

  Scenario: Infer Version from Manifest File
    Given a file “.release-please-manifest.json” containing:
      “””
      {
        “.”: “1.8.2”,
        “packages/service-a”: “0.4.1”
      }
      “””
    When the SBOM action runs with inputs:
      | input               | value                        |
      | source-name         | core-service                 |
      | source-version      |                              |
      | release-please-file | .release-please-manifest.json|
    Then the action output “resolved-version” should equal “1.8.2”
    And the SBOM metadata version should equal “1.8.2”

  Scenario: Explicit Version Overrides Release-Please Manifest
    Given a file “.release-please-manifest.json” containing:
      “””
      { “.”: “1.8.2” }
      “””
    When the SBOM action runs with inputs:
      | input          | value  |
      | source-version | 3.0.0  |
    Then the action output “resolved-version” should equal “3.0.0”
```

### Feature 3: Attestation & Opt-In Package Distribution

```gherkin
Feature: Attestation and Multi-Target Package Distribution
  As a Security Auditor
  I want optional attestation and package-embedding capabilities
  So that software artifacts across different registries carry signed provenance.

  Scenario: GitHub Artifact Attestation Enabled
    Given a valid CISA-compliant “sbom.json”
    When the action input “attest” is set to “true”
    Then the action executes “actions/attest-sbom” targeting “sbom.json”
    And a valid cryptographic provenance attestation is created.

  Scenario: Opt-In Container Registry Attachment (GHCR)
    Given a built OCI container image “ghcr.io/my-org/my-app:v1.0.0”
    When the action runs with inputs:
      | input       | value                          |
      | attach-ghcr | true                           |
      | target      | ghcr.io/my-org/my-app:v1.0.0   |
    Then “cosign attach sbom” is invoked against “ghcr.io/my-org/my-app:v1.0.0”

  Scenario: Opt-In Language Archive Embedding (Maven JAR)
    Given a compiled Java archive at “build/libs/service-1.0.0.jar”
    When the action runs with inputs:
      | input             | value                       |
      | package-type      | maven                       |
      | package-file-path | build/libs/service-1.0.0.jar|
    Then the file “META-INF/sbom/application-sbom.json” exists inside “build/libs/service-1.0.0.jar”
```

## 3. TDD Strategy & Implementation Plan

### Test Suite Structure

```
.
├── .github/
│   └── workflows/
│       ├── test-unit.yml
│       └── test-e2e.yml
├── action.yml
├── scripts/
│   ├── resolve-version.sh
│   ├── enrich-cisa.sh
│   └── attach-package.sh
└── tests/
    ├── unit/
    │   ├── resolve-version.test.bats
    │   ├── enrich-cisa.test.bats
    │   └── attach-package.test.bats
    └── fixtures/
        ├── sample-syft-output.json
        └── .release-please-manifest.json
```

### Component Test Cases (Using BATS - Bash Automated Testing System)

#### Unit Test 1: Version Resolution Logic (tests/unit/resolve-version.test.bats)
```bash
#!/usr/bin/env bats

setup() {
  export FIXTURE_DIR=“tests/fixtures”
}

@test “resolve-version: uses explicit version when provided” {
  run scripts/resolve-version.sh “2.0.0” “${FIXTURE_DIR}/.release-please-manifest.json” “.”
  [ “$status” -eq 0 ]
  [ “$output” = “2.0.0” ]
}

@test “resolve-version: parses root version from release-please manifest” {
  run scripts/resolve-version.sh “” “${FIXTURE_DIR}/.release-please-manifest.json” “.”
  [ “$status” -eq 0 ]
  [ “$output” = “1.8.2” ]
}

@test “resolve-version: falls back to git describe if manifest missing” {
  run scripts/resolve-version.sh “” “non-existent-file.json” “.”
  [ “$status” -eq 0 ]
  [[ “$output” =~ ^[0-9]+\.[0-9]+\.[0-9]+.* ]]
}
```

#### Unit Test 2: CISA JSON Enrichment (tests/unit/enrich-cisa.test.bats)

```bash
#!/usr/bin/env bats

setup() {
  export INPUT_FILE=“tests/fixtures/sample-syft-output.json”
  export OUTPUT_FILE=“$(mktemp)”
}

teardown() {
  rm -f “$OUTPUT_FILE”
}

@test “enrich-cisa: injects authors, supplier, and generationContext” {
  run scripts/enrich-cisa.sh \
    —input “$INPUT_FILE” \
    —output “$OUTPUT_FILE” \
    —name “my-app” \
    —version “1.0.0” \
    —author “Security Team” \
    —supplier “Acme Inc” \
    —context “post-build”

  [ “$status” -eq 0 ]
  
  run jq -r ‘.metadata.authors[0].name’ “$OUTPUT_FILE”
  [ “$output” = “Security Team” ]

  run jq -r ‘.metadata.supplier.name’ “$OUTPUT_FILE”
  [ “$output” = “Acme Inc” ]

  run jq -r ‘.metadata.properties[] | select(.name==“cisa:generationContext”).value’ “$OUTPUT_FILE”
  [ “$output” = “post-build” ]
}
```

## 4. Implementation Details

### Step 1: scripts/resolve-version.sh

```bash
#!/usr/bin/env bash
set -euo pipefail

EXPLICIT_VERSION=“${1:-}”
MANIFEST_FILE=“${2:-.release-please-manifest.json}”
TARGET_DIR=“${3:-.}”

if [ -n “$EXPLICIT_VERSION” ]; then
  echo “$EXPLICIT_VERSION”
  exit 0
fi

if [ -f “$MANIFEST_FILE” ]; then
  # Try relative target path first, fallback to root path “.”
  RESOLVED_VER=$(jq -r —arg path “$TARGET_DIR” ‘.[$path] // .[“.”] // empty’ “$MANIFEST_FILE” 2>/dev/null || true)
  if [ -n “$RESOLVED_VER” ]; then
    echo “$RESOLVED_VER”
    exit 0
  fi
fi

# Fallback to git tag/hash descriptor
git describe —tags —always 2>/dev/null || echo “0.0.0-draft”
```

### Step 2: scripts/enrich-cisa.sh

```bash
#!/usr/bin/env bash
set -euo pipefail

INPUT_FILE=“”
OUTPUT_FILE=“”
NAME=“”
VERSION=“”
AUTHOR=“”
SUPPLIER=“”
CONTEXT=“post-build”

while [[ $# -gt 0 ]]; do
  case $1 in
    —input) INPUT_FILE=“$2”; shift 2 ;;
    —output) OUTPUT_FILE=“$2”; shift 2 ;;
    —name) NAME=“$2”; shift 2 ;;
    —version) VERSION=“$2”; shift 2 ;;
    —author) AUTHOR=“$2”; shift 2 ;;
    —supplier) SUPPLIER=“$2”; shift 2 ;;
    —context) CONTEXT=“$2”; shift 2 ;;
    *) shift ;;
  esac
done

jq \
  —arg name “$NAME” \
  —arg version “$VERSION” \
  —arg author “$AUTHOR” \
  —arg supplier “$SUPPLIER” \
  —arg context “$CONTEXT” \
  ‘
  .metadata.component.name = $name |
  .metadata.component.version = $version |
  .metadata.authors = ( (.metadata.authors // []) + [{“name”: $author}] | unique ) |
  (if $supplier != “” then .metadata.supplier = {“name”: $supplier} else . end) |
  .metadata.properties = ( (.metadata.properties // []) + [{“name”: “cisa:generationContext”, “value”: $context}] | unique_by(.name) )
  ‘ “$INPUT_FILE” > “$OUTPUT_FILE”
```
  
### Step 3: scripts/attach-package.sh

```bash
#!/usr/bin/env bash
set -euo pipefail

PACKAGE_TYPE=“${1:-none}”
FILE_PATH=“${2:-}”
SBOM_PATH=“${3:-sbom.json}”

if [ “$PACKAGE_TYPE” = “none” ] || [ -z “$FILE_PATH” ]; then
  exit 0
fi

if [ ! -f “$FILE_PATH” ]; then
  echo “Error: Target package file $FILE_PATH not found.” >&2
  exit 1
fi

case “$PACKAGE_TYPE” in
  npm)
    # For npm tarballs (.tgz), extract, insert sbom.json in package/, recompress
    TMP_DIR=$(mktemp -d)
    tar -xzf “$FILE_PATH” -C “$TMP_DIR”
    cp “$SBOM_PATH” “$TMP_DIR/package/sbom.json”
    tar -czf “$FILE_PATH” -C “$TMP_DIR” package
    rm -rf “$TMP_DIR”
    ;;
  maven)
    # For Java archives (JAR/WAR/EAR), append under META-INF/sbom/
    TMP_DIR=$(mktemp -d)
    mkdir -p “$TMP_DIR/META-INF/sbom”
    cp “$SBOM_PATH” “$TMP_DIR/META-INF/sbom/application-sbom.json”
    zip -g -r “$FILE_PATH” META-INF/
    rm -rf “$TMP_DIR”
    ;;
  nuget)
    # For NuGet packages (.nupkg), inject into root payload
    zip -g “$FILE_PATH” “$SBOM_PATH”
    ;;
  *)
    echo “Unsupported package-type: $PACKAGE_TYPE” >&2
    exit 1
    ;;
esac
```

### Step 4: action.yml Implementation

```yaml
name: ‘CISA-Conformant Syft SBOM & Attestation Generator’
description: ‘Generates enriched CISA-compliant SBOMs, provides GitHub Attestations, and attaches to packages.’
inputs:
  target:
    description: ‘Target path or container image to scan’
    required: false
    default: ‘.’
  source-name:
    description: ‘Component/Product name’
    required: true
  source-version:
    description: ‘Explicit version (overrides release-please)’
    required: false
    default: ‘’
  release-please-file:
    description: ‘Path to release-please manifest file’
    required: false
    default: ‘.release-please-manifest.json’
  author:
    description: ‘SBOM Author name’
    required: false
    default: ‘${{ github.repository_owner }}’
  supplier:
    description: ‘Organization supplier name’
    required: false
    default: ‘’
  generation-context:
    description: ‘CISA Lifecycle context (build, post-build, pre-build, source)’
    required: false
    default: ‘post-build’
  attest:
    description: ‘Sign and create GitHub Artifact Attestation’
    required: false
    default: ‘true’
  attach-ghcr:
    description: ‘Push SBOM to GHCR via Cosign (requires target to be image reference)’
    required: false
    default: ‘false’
  attach-release:
    description: ‘Upload SBOM asset to GitHub Release’
    required: false
    default: ‘false’
  release-tag:
    description: ‘Target release tag for upload’
    required: false
    default: ‘’
  package-type:
    description: ‘Archive type to inject SBOM into: (none|npm|maven|nuget)’
    required: false
    default: ‘none’
  package-file-path:
    description: ‘Path to local archive artifact file’
    required: false
    default: ‘’

outputs:
  sbom-path:
    description: ‘Path to enriched CISA sbom.json’
    value: ‘${{ steps.cisa-enrich.outputs.sbom-path }}’
  resolved-version:
    description: ‘Version applied to metadata’
    value: ‘${{ steps.version.outputs.version }}’

runs:
  using: ‘composite’
  steps:
    - name: Resolve Application Version
      id: version
      shell: bash
      run: |
        VER=$(“${{ github.action_path }}/scripts/resolve-version.sh” \
          “${{ inputs.source-version }}” \
          “${{ inputs.release-please-file }}” \
          “${{ inputs.target }}”)
        echo “version=${VER}” >> $GITHUB_OUTPUT

    - name: Install Syft
      uses: anchore/scan-action/servicenow-dependencies/install-syft@v3
      with:
        syft-version: ‘v1.0.0’

    - name: Generate Base CycloneDX SBOM
      shell: bash
      env:
        SYFT_FILE_METADATA_SELECTION: ‘all’
      run: |
        syft “${{ inputs.target }}” -o cyclonedx-json=raw-sbom.json

    - name: Enrich Metadata for CISA Compliance
      id: cisa-enrich
      shell: bash
      run: |
        “${{ github.action_path }}/scripts/enrich-cisa.sh” \
          —input raw-sbom.json \
          —output sbom.json \
          —name “${{ inputs.source-name }}” \
          —version “${{ steps.version.outputs.version }}” \
          —author “${{ inputs.author }}” \
          —supplier “${{ inputs.supplier }}” \
          —context “${{ inputs.generation-context }}”
        
        echo “sbom-path=$(pwd)/sbom.json” >> $GITHUB_OUTPUT

    - name: Attest SBOM (GitHub Sigstore Attestation)
      if: inputs.attest == ‘true’
      uses: actions/attest-sbom@v1
      with:
        subject-path: ‘${{ steps.cisa-enrich.outputs.sbom-path }}’
        sbom-path: ‘${{ steps.cisa-enrich.outputs.sbom-path }}’

    - name: Attach to OCI Image in GHCR
      if: inputs.attach-ghcr == ‘true’
      shell: bash
      run: |
        cosign attach sbom —sbom sbom.json “${{ inputs.target }}”

    - name: Attach to GitHub Release
      if: inputs.attach-release == ‘true’ && inputs.release-tag != ‘’
      shell: bash
      env:
        GH_TOKEN: ${{ github.token }}
      run: |
        gh release upload “${{ inputs.release-tag }}” sbom.json#cisa-sbom.json —clobber

    - name: Embed SBOM in Package Payload
      if: inputs.package-type != ‘none’
      shell: bash
      run: |
        “${{ github.action_path }}/scripts/attach-package.sh” \
          “${{ inputs.package-type }}” \
          “${{ inputs.package-file-path }}” \
          “sbom.json”
``` 

## 5. End-User Integration Runbook

This section details setup recipes for development teams integrating this action into their repositories.

### Prerequisites & Permissions

Your workflow job must contain the following GitHub permissions to generate attestations and push assets to registries:

```yaml
permissions:
  contents: write        # Required for GitHub Release upload
  packages: write        # Required for GHCR push
  id-token: write        # Required for GitHub Sigstore Artifact Attestation
  attestations: write    # Required for GitHub Artifact Attestation write
```

### Scenario A: Standalone CISA SBOM with Automated release-please

```yaml
name: Security & Release Pipelines

on:
  push:
    branches: [ main ]

jobs:
  release:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      id-token: write
      attestations: write
    steps:
      - uses: actions/checkout@v4

      - name: Run Release-Please
        id: release
        uses: googleapis/release-please-action@v4
        with:
          release-type: node

      - name: Generate & Attest CISA SBOM
        uses: vln-devsecops/actions-cisa-sbom@v1
        with:
          source-name: ‘my-microservice’
          release-please-file: ‘.release-please-manifest.json’
          author: ‘SecOps Team’
          supplier: ‘Acme Software Enterprise’
          generation-context: ‘post-build’
          attest: ‘true’
```

### Scenario B: Container Build with GHCR Attestation & OCI Attachment

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
      - uses: actions/checkout@v4

      - name: Log in to GHCR
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build and Push Docker Image
        run: |
          docker build -t ghcr.io/${{ github.repository }}:v1.2.0 .
          docker push ghcr.io/${{ github.repository }}:v1.2.0

      - name: Install Cosign
        uses: sigstore/cosign-installer@v3

      - name: Generate SBOM and Attach to GHCR
        uses: vln-devsecops/actions-cisa-sbom@v1
        with:
          target: ‘ghcr.io/${{ github.repository }}:v1.2.0’
          source-name: ‘my-app-container’
          source-version: ‘1.2.0’
          attach-ghcr: ‘true’
          attest: ‘true’
```

### Scenario C: Embedded Language Package (Java / Maven JAR Distribution)

```yaml
jobs:
  package-java:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      id-token: write
      attestations: write
    steps:
      - uses: actions/checkout@v4

      - name: Build Java Package
        run: ./gradlew build

      - name: Generate SBOM and Embed into JAR
        uses: vln-devsecops/actions-cisa-sbom@v1
        with:
          source-name: ‘billing-api’
          source-version: ‘2.1.0’
          package-type: ‘maven’
          package-file-path: ‘build/libs/billing-api-2.1.0.jar’
          attest: ‘true’

      - name: Publish Artifact
        run: ./gradlew publish
```
