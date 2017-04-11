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
