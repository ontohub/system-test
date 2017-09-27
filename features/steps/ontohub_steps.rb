# frozen_string_literal: true

# This isn't an example for future tests, it's just a test for the database rollback

When(/^I add a user to the database$/) do
  system(%(psql -d #{$database_name} -U postgres -c "INSERT INTO organizational_units (display_name, kind, slug) VALUES ('Charlie Chocolate', 'User', 'charliechocolate')"))
end

Then(/^the user should be there$/) do
  steps %(
    When I run `psql -d #{$database_name} -U postgres -t -c 'SELECT * FROM organizational_units'`
    Then the output from "psql -d #{$database_name} -U postgres -t -c 'SELECT * FROM organizational_units'" should contain "charliechocolate"
  )
end

When(/^I do a rollback$/) do
  system(%(psql -d #{$database_name} -U postgres -c "SELECT emaj.emaj_rollback_group('system-test', 'EMAJ_LAST_MARK');"))
end

Then(/^the user shouldn't be there$/) do
  steps %(
    When I run `psql -d #{$database_name} -U postgres -t -c 'SELECT * FROM organizational_units'`
    Then the output from "psql -d #{$database_name} -U postgres -t -c 'SELECT * FROM organizational_units'" should not contain "charliechocolate"
  )
end

# Steps belong to 'Login' scenario

Given(/^I visit the start page$/) do
  visit('/')
end

When(/^I click on the 'Sign in' button$/) do
  find('#login-modal-sign-in-button').click
end

When(/^I enter my credentials and click the 'Sign in' button$/) do
  fill_in 'sign-in-username', with: 'ada'
  fill_in 'sign-in-password', with: 'changemenow'
  find('#sign-in-form-sign-in-button').click
end

Then(/^I should be logged in$/) do
  find('.right.menu .ui.item.dropdown .react-gravatar').click
  expect(page).to have_content('SIGNED IN AS')
end











Given(/^I am logged in$/) do
  find('.top-bar-right a#sign_in_menu_link').click
  within('form#login') do
    fill_in 'username', with: 'ada'
    fill_in 'password', with: 'changeme'
    click_button 'Sign in'
  end
  find('.top-bar-right a#user_menu_link').click
  expect(page).to have_content('Signed in as')
end

When(/^I visit the repository creation page$/) do
  find('.top-bar-right a#new-menu-link').click
  click_link('New repository')
  expect(page).to have_content('Create a new repository')
end

When(/^I create a repository$/) do
  $repository_name = Faker::Name.title
  within('fieldset#repository-new-name') do
    fill_in 'Name', with: $repository_name
  end
  within('fieldset#repository-new-description') do
    fill_in 'Description', with: Faker::Lorem.sentence
  end
  within('fieldset#repository-new-content-type') do
    choose('Model')
  end
  within('fieldset#repository-new-access') do
    choose('Public')
  end
  click_button 'Save'
end

Then(/^I should see the repository page$/) do
  expect(page).to have_content("ada / #{$repository_name}")
end


Then(/^the repository should be visible in the repository overview page$/) do
  visit('/search')
  expect(page).to have_content("ada/#{$repository_name.parameterize}")
end

Then(/^the repository should be in the backend$/) do
  steps %{
    When I run `curl -i -L -H "Content-Type: application/json" -H "Accept: application/vnd.api+json" http://localhost:#{$backend_port}/ada/#{$repository_name.parameterize}`
    Then the exit status should be 0
    And the output contains a line "HTTP/1.1 200 OK"
  }
end

Then(/^the output contains a line "([^"]*)"$/) do |arg|
  expect(extract_text(unescape_text(last_command_started.output))).to match(/#{arg}/)
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
  @description = 'Changed description of repo0'
  expect(page).to have_content(@description)
end

Then(/^the changed repository should be in the backend$/) do
  steps %{
    When I run `curl -i -L -H "Content-Type: application/json" -H "Accept: application/vnd.api+json" http://localhost:#{$backend_port}/ada/repo0`
    Then the exit status should be 0
    And the output should contain "#{@description}"
  }
end

Given(/^I visit a non\-existent page$/) do
  visit('/non-existent')
end

Then(/^I should see the error page$/) do
  expect(page).to have_content('Error The server responded with an error')
  expect(page).to have_css('a', text: 'Go back')
  expect(page).to have_link('Home')
end
