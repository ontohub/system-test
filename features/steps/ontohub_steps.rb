# This isn't an example for future tests, it's just a test for the database rollback

When(/^I add a user to the database$/) do
  system(%(psql -d ontohub_test -U postgres -c "INSERT INTO users (id, real_name, email, encrypted_password) VALUES (3, 'Charlie', 'charlie@example.com', 'supersafe')"))
end

Then(/^the user should be there$/) do
  steps %{
    When I run `psql -d ontohub_test -U postgres -t -c 'SELECT * FROM users'`
    Then the output from "psql -d ontohub_test -U postgres -t -c 'SELECT * FROM users'" should contain "charlie@example.com"
  }
end

When(/^I do a rollback$/) do
  system(%(psql -d ontohub_test -U postgres -c "SELECT emaj.emaj_rollback_group('system-test', 'EMAJ_LAST_MARK');"))
end

Then(/^the user shouldn't be there$/) do
  steps %{
    When I run `psql -d ontohub_test -U postgres -t -c 'SELECT * FROM users'`
    Then the output from "psql -d ontohub_test -U postgres -t -c 'SELECT * FROM users'" should not contain "charlie@example.com"
  }
end
