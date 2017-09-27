# frozen_string_literal: true

require 'active_support/inflector'
require 'aruba/cucumber'
require 'capybara/cucumber'
require 'capybara/poltergeist'
require 'faker'

$github_ontohub = 'https://github.com/ontohub/'
$frontend_port = 3002
$backend_port = 3003
$database_name = 'ontohub_system_test'

Capybara.configure do |c|
  c.javascript_driver = :poltergeist
  c.default_driver = :poltergeist
  c.app_host = "http://localhost:#{$frontend_port}"
  c.default_max_wait_time = 5
end

Capybara.register_driver :poltergeist do |app|
  Capybara::Poltergeist::Driver.new(app, js_errors: true, debug: true)
end

# Capybara is smart enough to wait for ajax when not finding elements.
# In some situations the element is already existent, but has not been updated
# yet. This is where you need to manually use wait_for_ajax.
def wait_for_ajax(wait_time = Capybara.default_max_wait_time)
  counter = 0
  # The condition only works with poltergeist/phantomjs.
  while page.evaluate_script('$.active').to_i.positive?
    counter += 1
    sleep(0.1)
    if counter >= 10 * wait_time
      raise 'AJAX request took longer than 5 seconds.'
    end
  end
end
