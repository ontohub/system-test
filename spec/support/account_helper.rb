# frozen_string_literal: true

module AccountHelper
  # Helper methods to use in the specs to sign in and call the API.
  module InstanceMethods
    def sign_in(user, password)
      page.visit('/')
      page.find('#login-modal-sign-in-button').click
      page.fill_in 'sign-in-username', with: user
      page.fill_in 'sign-in-password', with: password
      page.find('#sign-in-form-sign-in-button').click
    end

    # rubocop:disable Metrics/MethodLength
    def sign_in_api(user, password)
      # rubocop:enable Metrics/MethodLength
      raw_query = <<~QUERY
        mutation ($username: String!, $password: String!) {
          signIn(username: $username, password: $password) {
            jwt
            me {
              id
              displayName
            }
          }
        }
      QUERY
      api_call(raw_query, {'username' => user, 'password' => password}, nil)
    end

    # rubocop:disable Metrics/MethodLength
    def save_public_key(authorization_token, public_key)
      # rubocop:enable Metrics/MethodLength
      raw_query = <<~QUERY
        mutation ($key:String!) {
          addPublicKey(key: $key) {
            name
            key
            fingerprint
          }
        }
      QUERY
      api_call(raw_query,
               {'key' => public_key},
               "Bearer #{authorization_token}")
    end

    def api_call(raw_query, variables_hash, authorization = nil)
      response = raw_api_call(raw_query, variables_hash, authorization)
      JSON.parse(response)
    end

    def raw_api_call(raw_query, variables_hash, authorization = nil)
      command =
        %(curl -s '#{backend_url}/graphql' ) +
        (authorization ? "-H 'Authorization: #{authorization}' " : '') +
        %(-H 'Content-Type: application/json' ) +
        %(-H 'Accept: application/json' ) +
        %(--data-binary '{"query":"#{raw_query.gsub("\n", '\n')}",) +
        %("variables":#{variables_hash.to_json}}')
      `#{command}`
    end

    def travis_public_key
      File.read('/home/travis/.ssh/self.pub').strip
    end
  end
end

RSpec.configure do |config|
  config.include AccountHelper::InstanceMethods
end
