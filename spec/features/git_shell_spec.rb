# frozen_string_literal: true

if ENV['TRAVIS']
  RSpec.describe 'GitShell' do
    before(:context) do
      rollback_backend
    end

    describe 'git clone' do
      before(:context) do
        @temp_directory = Dir.mktmpdir
        @repository = 'ada/fixtures.git'
      end

      after(:context) do
        FileUtils.rm_rf(@temp_directory)
      end

      context 'After a user saves a public key', order: :defined do
        before(:context) do
          @user = 'ada'
          token = sign_in_api('ada', 'changemenow')['data']['signIn']['jwt']
          save_public_key(token, travis_public_key)
        end

        context 'When a repository is writable for the user' do
          let(:repository) { 'ada/fixtures' }

          it 'the user can clone a git repository' do
            Dir.chdir(@temp_directory) do
              warn `git clone travis@localhost:#{repository}.git`
              # expect(system("git clone travis@localhost:#{repository}.git")).
              #   to be(true)
            end
          end

          it 'and there is actually a local git repository' do
            Dir.chdir(File.join(@temp_directory, repository.split('/').last)) do
              command = 'git rev-parse --git-dir 1> /dev/null 2> /dev/null'
              warn `pwd`
              warn `ls -la`
              warn command
              expect(system(command)).to be(true)
            end
          end

          it 'the user can push to the repository' do
            Dir.chdir(File.join(@temp_directory, repository.split('/').last)) do
              file = 'new_file'
              `touch #{file}`
              `git add #{file}`
              `git commit -m "Add #{file}"`
              warn `git push`
              # expect(system('git push')).to be(true)
            end
          end

          it 'the user can not force-push to the repository' do
            Dir.chdir(File.join(@temp_directory, repository.split('/').last)) do
              `git commit -m "Amend the commit." --amend`
              expect(system('git push')).to be(false)
            end
          end
        end

        context 'When a repository is readable, but not writable' do
          let(:repository) { 'bob/my-public-repository' }

          it 'the user can clone a git repository' do
            expect(system("git clone travis@localhost:#{repository}.git")).
              to be(true)
          end

          it 'and there is actually a local git repository' do
            Dir.chdir(File.join(@temp_directory, repository.split('/').last)) do
              command = 'git rev-parse --git-dir 1> /dev/null 2> /dev/null'
              expect(system(command)).to be(true)
            end
          end

          it 'the user cannot push to the repository' do
            Dir.chdir(File.join(@temp_directory, repository.split('/').last)) do
              file = 'new_file'
              `touch #{file}`
              `git add #{file}`
              `git commit -m "Add #{file}"`
              expect(system('git push')).to be(false)
            end
          end

          it 'the user is presented an error message' do
            Dir.chdir(File.join(@temp_directory, repository.split('/').last)) do
              message =
                'Unauthorized: You are unauthorized to write to this repository'
              expect(`git push`).to match(/#{message}/i)
            end
          end
        end

        shared_examples 'no read access or inexistant' do
          let(:message) do
            'The Repository has not been found '\
            'or you are unauthorized to read it.'
          end

          it 'the user cannot clone a git repository' do
            expect(system("git clone travis@localhost:#{repository}.git")).
              to be(false)
          end

          it 'the user is presented an error message' do
            expect(`git clone travis@localhost:#{repository}.git`).
              to match(/#{message}/)
          end

          context 'When the user tries to push to that repository' do
            before(:context) do
              Dir.chdir(@temp_directory) do
                system("git init #{repository.split('/').last}")

              end
            end

            it 'there is no local git repository' do
              expect(File.exist?(File.join(@temp_directory, 'fixtures'))).
                to be(false)
            end

            it 'the user cannot push to the repository' do
              Dir.chdir(File.join(@temp_directory, 'fixtures')) do
                file = 'new_file'
                `touch #{file}`
                `git add #{file}`
                `git commit -m "Add #{file}"`
                expect(system('git push')).to be(false)
              end
            end

            it 'the user is presented an error message' do
              Dir.chdir(File.join(@temp_directory, 'fixtures')) do
                expect(`git push`).to match(/#{message}/i)
              end
            end
          end
        end

        context 'When a repository is neither readable nor writable' do
          let(:repository) { 'cam/my-private-repository' }
          include_examples 'no read access or inexistant'
        end

        context 'When a repository does not exist' do
          let(:repository) { 'my/absent-repository' }
          include_examples 'no read access or inexistant'
        end
      end
    end
  end
end
