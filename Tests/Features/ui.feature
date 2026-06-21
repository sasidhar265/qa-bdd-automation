Feature: Cypress kitchen sink UI

Scenario: Open homepage and verify title
    Given I open the test site
    Then The title should contain "Cypress.io: Kitchen Sink"
