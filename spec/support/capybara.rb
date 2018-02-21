# frozen_string_literal: true

require 'active_support/inflector'
require 'capybara/rspec'
require 'selenium/webdriver'

require_relative 'applications.rb'

Capybara.register_driver :chrome do |app|
  Capybara::Selenium::Driver.new(app, browser: :chrome)
end

Capybara.register_driver :headless_chrome do |app|
  capabilities = Selenium::WebDriver::Remote::Capabilities.chrome(
    chromeOptions: {args: %w(headless disable-gpu)}
  )

  Capybara::Selenium::Driver.new app,
    browser: :chrome,
    desired_capabilities: capabilities
end

Capybara.javascript_driver = :headless_chrome

Capybara.configure do |c|
  c.default_driver = :headless_chrome
  c.javascript_driver = :headless_chrome
  c.app_host = "http://localhost:#{Applications::FRONTEND_PORT}"
  c.default_max_wait_time = 5
end

# Capybara is smart enough to wait for ajax when not finding elements.
# In some situations the element is already existent, but has not been updated
# yet. This is where you need to manually use wait_for_ajax.
module CapybaraHelpers
  def wait_for_ajax(wait_time = Capybara.default_max_wait_time)
    counter = 0
    # The condition only works with a javascript-running browser
    while page.evaluate_script('$.active').to_i.positive?
      counter += 1
      sleep(0.1)
      if counter >= 10 * wait_time
        raise 'AJAX request took longer than 5 seconds.'
      end
    end
  end
end

RSpec.configure do |config|
  config.include CapybaraHelpers
end
