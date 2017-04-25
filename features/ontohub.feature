Feature: Ontohub

  In order to test our complete Ontohub application
  We want to clone all relevant repos and then run the following scenarios

  Scenario: Run the init script
  Then the following directories should exist:
    | ../../ontohub-frontend |
    | ../../ontohub-backend |
    | ../../hets-rabbitmq-wrapper |
  When I run `curl --connect-timeout 30 localhost:3000`
  Then the exit status should be 0
  When I run `curl --connect-timeout 30 localhost:4200`
  Then the exit status should be 0

  Scenario: Successful rollback
  When I add a user to the database
  Then the user should be there
  When I do a rollback
  Then the user shouldn't be there

  @javascript
  Scenario: Create a repository
  Given I visit the start page
  And I am logged in
  When I visit the repository creation page
  And I create a repository
  Then the repository should be visible in the repository overview page
  And the repository should be in the backend

  @javascript
  Scenario: Edit a repository
  Given I visit the start page
  And I am logged in and there is a repository I created
  When I change the description of the repository
  Then the changed repository should be visible in the repository overview page
  And the changed repository should be in the backend
