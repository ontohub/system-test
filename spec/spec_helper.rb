# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'bundler'
require 'faker'
require 'pry'

Dir.glob('spec/support/**/*.rb').each do |file|
  require_relative file.sub(%r{\Aspec/}, '')
end

Dir.glob('spec/shared_examples/**/*.rb').each do |file|
  require_relative file.sub(%r{\Aspec/}, '')
end

RSpec.configure do |config|
end
