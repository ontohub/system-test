# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'bundler'
require 'faker'
require 'open3'
require 'pry'

Dir.glob('spec/support/**/*.rb').each do |file|
  require_relative file.sub(%r{\Aspec/}, '')
end

Dir.glob('spec/shared_examples/**/*.rb').each do |file|
  require_relative file.sub(%r{\Aspec/}, '')
end

RSpec.configure do |config|
  config.order = :random
  # Configure faker to use the RSpec seed
  Faker::Config.random = Random.new(config.seed)
  # Configure ruby to use the RSpec seed for randomization
  srand config.seed

  config.include Open3
end
