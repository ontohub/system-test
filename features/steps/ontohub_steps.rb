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

# Steps belong to 'create repository' scenario

Given(/^I visit the start page$/) do
  visit('/')
end

Given(/^I am logged in$/) do
  find('.top-bar-right a#sign_in_menu_link').click
  within('form#login') do
    fill_in 'username', with: 'ada'
    fill_in 'password', with: 'changeme'
    click_button 'Sign in'
  end
  find('.top-bar-right').find('a#user_menu_link').click
  expect(page).to have_content('Signed in as')
end

When(/^I visit the repository creation page$/) do
  find('.top-bar-right a#new_menu_link').click
  click_link('New repository')
  expect(page).to have_content('Create a new repository')
end

When(/^I create a repository$/) do
  $repository_name = Faker::Name.title
  within('fieldset#repository_new_name') do
    fill_in 'Name', with: $repository_name
  end
  within('fieldset#repository_new_description') do
    fill_in 'Description', with: Faker::Lorem.sentence
  end
  within('fieldset#repository_new_content_type') do
    choose('Model')
  end
  within('fieldset#repository_new_access') do
    choose('Public')
  end
  click_button 'Save'
  expect(page).to have_content("ada / #{$repository_name}")
end

Then(/^the repository should be visible in the repository overview page$/) do
  visit('/search')
  expect(page).to have_content("ada/#{$repository_name.gsub(/\s/, '-').downcase}")
end

Then(/^the repository should be in the backend$/) do
  steps %{
    When I run `curl -i -L -H "Content-Type: application/json" -H "Accept: application/vnd.api+json" http://localhost:3000/ada/#{$repository_name.gsub(/\s/, '-').downcase}`
    Then the exit status should be 0
    And the output should contain "200 OK"
  }
end

# Steps belong to 'edit repository' scenario

Given(/^I am logged in and there is a repository I created$/) do
  steps %{
    Given I am logged in
  }
end

When(/^I change the description of the repository$/) do
  visit('/ada/repo0')
  find('.top-route-header span').click
  find('.input-group-field').set('Changed description of repo0')
  find('.input-group-button button').click
  wait_for_ajax #Wait for the changed description
end

Then(/^the changed repository should be visible in the repository overview page$/) do
  visit('/search')
  expect(page).to have_content('Changed description of repo0')
end

Then(/^the changed repository should be in the backend$/) do
  steps %{
    When I run `curl -i -L -H "Content-Type: application/json" -H "Accept: application/vnd.api+json" http://localhost:3000/ada/repo0`
    Then the exit status should be 0
    And the output should contain "Changed description of repo0"
  }
end
