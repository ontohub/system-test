# frozen_string_literal: true

if ENV['TRAVIS']
  RSpec.describe 'GitShell' do
    before(:context) do
      reset_backend
    end

    describe 'git clone' do
      before(:context) do
        @temp_directory = Dir.mktmpdir
        @repository = 'ada/fixtures.git'
      end

      after(:context) do
        FileUtils.rm_rf(@temp_directory)
      end

      context 'After the user saves a public key', order: :defined do
        before(:context) do
          @user = 'ada'
          token = sign_in_api('ada', 'changemenow')['data']['signIn']['jwt']
          save_public_key(token, travis_public_key)
        end

        it 'they can clone a git repository' do
          expect(system('git clone travis@localhost:ada/fixtures.git')).
            to be(true)
        end

        it 'and there is actually a local git repository' do
          Dir.chdir(File.join(@temp_directory, 'fixtures')) do
            expect(system('git rev-parse --git-dir 1> /dev/null 2> /dev/null')).
              to be(true)
          end
        end

        it 'they can push to the repository' do
          Dir.chdir(File.join(@temp_directory, 'fixtures')) do
            file = 'new_file'
            `touch #{file}`
            `git add #{file}`
            `git commit -m "Add #{file}"`
            expect(system('git push')).to be(true)
          end
        end
      end
    end
  end
end
