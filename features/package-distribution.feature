Feature: Attestation and Multi-Target Package Distribution
  As a Security Auditor
  I want optional attestation and package-embedding capabilities
  So that software artifacts across different registries carry signed provenance.

  Scenario: Opt-In Language Archive Embedding (Maven JAR)
    Given a compiled Java archive at "build/libs/service-1.0.0.jar"
    When the action runs with inputs:
      | input             | value                         |
      | package-type      | maven                         |
      | package-file-path | build/libs/service-1.0.0.jar  |
    Then the file "META-INF/sbom/application-sbom.json" exists inside "build/libs/service-1.0.0.jar"

  Scenario: Opt-In Language Archive Embedding (npm Tarball)
    Given a packaged npm archive at "dist/my-package-1.0.0.tgz"
    When the action runs with inputs:
      | input             | value                     |
      | package-type      | npm                       |
      | package-file-path | dist/my-package-1.0.0.tgz |
    Then the file "package/sbom.json" should exist inside "dist/my-package-1.0.0.tgz"
