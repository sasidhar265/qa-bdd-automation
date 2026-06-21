Feature: User API

Scenario: Get users
    Given I send GET request to "/users"
    Then response status should be 200
