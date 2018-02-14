# frozen_string_literal: true

module SystemTestHelper
  module InstanceMethods
    def sql_output(command)
      `psql --no-psqlrc -d #{database_name} -U postgres -t -c "#{command}"`
    end
  end
end

RSpec.configure do |config|
  config.include SystemTestHelper::InstanceMethods
end
