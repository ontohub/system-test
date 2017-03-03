Feature: Ontohub

  In order to test our complete Ontohub application
  We want to clone all relevant repos and then run the following scenarios

  Scenario: Run the init script
  Then the following directories should exist:
    | ../../ontohub-frontend |
    | ../../ontohub-backend |
    | ../../hets-rabbitmq-wrapper |
  When I run `curl localhost:3000`
  Then the exit status should be 0
