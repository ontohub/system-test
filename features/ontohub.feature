Feature: Ontohub

  In order to test our complete Ontohub application
  We want to clone all relevant repos and then run the following scenarios

Scenario: Run the init script
  Then the following directories should exist:
    | ../../ontohub-frontend |
    | ../../ontohub-backend |
    | ../../hets-agent |
  When I run `curl --connect-timeout 30 localhost:3003`
  Then the exit status should be 0
  When I run `curl --connect-timeout 30 localhost:3002`
  Then the exit status should be 0

Scenario: Successful rollback
  When I add a user to the database
  Then the user should be there
  And the user 'ada' should be there
  When I do a rollback
  Then the user shouldn't be there
  And the user 'ada' should be there

@javascript
Scenario: Login
  Given I visit the start page
  When I click on the 'Sign in' button
  And I enter my credentials and click the 'Sign in' button
  Then I should be logged in

@javascript
Scenario: Logout
  Given I am logged in
  When I click on 'Sign out'
  Then I should be logged out
