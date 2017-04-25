require 'aruba/cucumber'
require 'capybara/cucumber'
require 'capybara/poltergeist'
require 'faker'

Capybara.configure do |c|
  c.javascript_driver = :poltergeist
  c.default_driver = :poltergeist
  c.app_host = 'http://localhost:4200'
  c.default_max_wait_time = 5
end
