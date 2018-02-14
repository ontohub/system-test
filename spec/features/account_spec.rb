# frozen_string_literal: true

RSpec.describe 'Account', type: :feature, js: true do
  before do
    rollback_frontend
  end

  describe 'Sign in' do
    context 'When the user signs in', order: :defined do
      let(:user) { 'ada' }
      let(:password) { 'changemenow' }

      before do
        sign_in(user, password)
      end

      it 'the page displays a signed in indicator in the user dropdown' do
        page.find('.right.menu .ui.item.dropdown .react-gravatar').click
        expect(page).to have_content('SIGNED IN AS')
      end

      it 'the page displays a sign out button in the user dropdown' do
        page.find('.right.menu .ui.item.dropdown .react-gravatar').click
        expect(page).to have_content('Sign out')
      end
    end
  end

  describe 'Sign out', order: :defined do
    context 'When a user is signed in and clicks on sign out' do
      let(:user) { 'ada' }
      let(:password) { 'changemenow' }

      before do
        sign_in(user, password)
        page.find('.right.menu .ui.item.dropdown .react-gravatar').click
        page.find('#global-menu-sign-out-button').click
      end

      it 'the user is signed out' do
        expect(page).to have_content('Sign in')
      end
    end
  end
end
