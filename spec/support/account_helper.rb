# frozen_string_literal: true

module AccountHelper
  module InstanceMethods
    def sign_in(user, password)
      page.visit('/')
      page.find('#login-modal-sign-in-button').click
      page.fill_in 'sign-in-username', with: user
      page.fill_in 'sign-in-password', with: password
      page.find('#sign-in-form-sign-in-button').click
    end
  end
end

RSpec.configure do |config|
  config.include AccountHelper::InstanceMethods
end
