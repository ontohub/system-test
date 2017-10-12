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
  expect(page).to have_content('Sign out')
end

# Steps belong to 'Logout' scenario

Given(/^I am logged in$/) do
  steps %{
    Given I visit the start page
    When I click on the 'Sign in' button
    And I enter my credentials and click the 'Sign in' button
    Then I should be logged in
  }
end

When(/^I click on 'Sign out'$/) do
  find('#global-menu-sign-out-button').click
end

Then(/^I should be logged out$/) do
  expect(page).to have_content('Sign in')
end
