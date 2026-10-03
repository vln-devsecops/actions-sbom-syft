Feature: CISA-Compliant Metadata Enrichment
  As a DevSecOps Engineer
  I want Syft SBOM outputs enriched with CISA minimum required fields
  So that downstream compliance tools validate our supply chain metadata.

  Scenario: Explicit Metadata Input
    Given a raw Syft CycloneDX SBOM
    When the enrichment runs with:
      | input              | value                |
      | source-name        | core-payment-service |
      | source-version     | 2.4.0                |
      | author             | DevSecOps Team        |
      | supplier           | Acme Corp             |
      | generation-context | post-build            |
    Then an enriched SBOM file is produced
    And the JSON property ".metadata.component.name" equals "core-payment-service"
    And the JSON property ".metadata.component.version" equals "2.4.0"
    And the JSON array ".metadata.authors" contains an entry with name "DevSecOps Team"
    And the JSON property ".metadata.supplier.name" equals "Acme Corp"
    And the JSON array ".metadata.properties" contains a property "cisa:generationContext" with value "post-build"
