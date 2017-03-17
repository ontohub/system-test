When(/^I add a user to the database$/) do
  system(%(psql -d ontohub_test -U postgres -c "INSERT INTO users (id, real_name, email, encrypted_password) VALUES (3, 'Charlie', 'charlie@example.com', 'supersafe')"))
end

Then(/^the user should be there$/) do
  steps %{
    When I run `psql -d ontohub_test -U postgres -c 'SELECT * FROM users WHERE id = 3'`
    Then the exit status should be 0
  }
end

When(/^I do a rollback$/) do
  system(%(psql -d ontohub_test -U postgres -c "SELECT emaj.emaj_rollback_group('system-test', 'EMAJ_LAST_MARK');"))
end

Then(/^the user shouldn be there$/) do
  steps %{
    When I run `psql -d ontohub_test -U postgres -c 'SELECT * FROM users WHERE id = 3'`
    Then the exit status should not be 0
  }
end
