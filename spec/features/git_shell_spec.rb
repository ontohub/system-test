# frozen_string_literal: true

if ENV['TRAVIS']
  RSpec.describe 'GitShell' do
    before(:context) do
      rollback_backend
    end

    describe 'git clone' do
      before(:context) do
        @repository = 'ada/fixtures'

        @client_temp_directory = Dir.mktmpdir
        @client_repository = File.join(@client_temp_directory, 'client')

        @control_temp_directory = Dir.mktmpdir
        @control_repository = File.join(@control_temp_directory, 'control')

        backend_local_repository = "#{data_dir.join('git', @repository)}.git"
        `git clone "#{backend_local_repository}" "#{@control_repository}"`
      end

      after(:context) do
        FileUtils.rm_rf(@client_temp_directory)
        FileUtils.rm_rf(File.dirname(@control_repository))
      end

      context 'After a user saves a public key' do
        before(:context) do
          @user = 'ada'
          token = sign_in_api('ada', 'changemenow')['data']['signIn']['jwt']
          save_public_key(token, travis_public_key)
        end

        context 'When a repository is writable for the user', order: :defined do
          let(:repository) { 'ada/fixtures' }

          it 'the user can clone a git repository' do
            Dir.chdir(@client_temp_directory) do
              command = %(git clone "travis@localhost:#{repository}" ) +
                        %("#{@client_repository}")
              expect(system(command)).to be(true)
            end
          end

          it 'and there is actually a local git repository' do
            Dir.chdir(@client_repository) do
              command = 'git rev-parse --git-dir 1> /dev/null 2> /dev/null'
              expect(system(command)).to be(true)
            end
          end

          context 'after the repository has changed on the server',
            order: :defined do
            before(:context) do
              Dir.chdir(@control_repository) do
                @file_changed_on_server = 'changed_on_server'
                `touch #{@file_changed_on_server}`
                `git add #{@file_changed_on_server}`
                `git commit -m "Add #{@file_changed_on_server}"`
                `git push`
              end
            end

            it 'the user can pull new changes' do
              expect(system('git pull')).to be(true)
            end

            it 'the user actually receives the changes' do
              expect(File.exist?(@file_changed_on_server)).to be(true)
            end
          end

          it 'the user can push to the repository' do
            Dir.chdir(@client_repository) do
              @file_changed_on_client = 'new_file'
              `touch #{@file_changed_on_client}`
              `git add #{@file_changed_on_client}`
              `git commit -m "Add #{@file_changed_on_client}"`
              expect(system('git push')).to be(true)
            end
          end

          it 'and the change is actually on the server' do
            Dir.chdir(@control_repository) do
              `git pull`
              expect(File.exist?(@file_changed_on_client)).to be(true)
            end
          end

          it 'the user can not force-push to the repository' do
            Dir.chdir(@client_repository) do
              `git commit -am "Amend the commit." --amend`
              @file_changed_on_client2 = 'new_file'
              `touch #{@file_changed_on_client2}`
              `git add #{@file_changed_on_client2}`
              `git commit -m "Add #{@file_changed_on_client2}"`
              expect(system('git push')).to be(false)
            end
          end

          it 'and the change is not on the server' do
            Dir.chdir(@control_repository) do
              `git pull`
              expect(File.exist?(@file_changed_on_client2)).to be(false)
            end
          end
        end

        # context 'When a repository is readable, but not writable' do
        #   let(:repository) { 'bob/my-public-repository' }

        #   it 'the user can clone a git repository' do
        #     expect(system("git clone travis@localhost:#{repository}")).
        #       to be(true)
        #   end

        #   it 'and there is actually a local git repository' do
        #     Dir.chdir(File.join(@temp_directory, repository.split('/').last)) do
        #       command = 'git rev-parse --git-dir 1> /dev/null 2> /dev/null'
        #       expect(system(command)).to be(true)
        #     end
        #   end

        #   it 'the user cannot push to the repository' do
        #     Dir.chdir(File.join(@temp_directory, repository.split('/').last)) do
        #       file = 'new_file'
        #       `touch #{file}`
        #       `git add #{file}`
        #       `git commit -m "Add #{file}"`
        #       expect(system('git push')).to be(false)
        #     end
        #   end

        #   it 'the user is presented an error message' do
        #     Dir.chdir(File.join(@temp_directory, repository.split('/').last)) do
        #       message =
        #         'Unauthorized: You are unauthorized to write to this repository'
        #       expect(`git push`).to match(/#{message}/i)
        #     end
        #   end
        # end

        # shared_examples 'no read access or inexistant' do
        #   let(:message) do
        #     'The Repository has not been found '\
        #     'or you are unauthorized to read it.'
        #   end

        #   it 'the user cannot clone a git repository' do
        #     expect(system("git clone travis@localhost:#{repository}")).
        #       to be(false)
        #   end

        #   it 'the user is presented an error message' do
        #     expect(`git clone travis@localhost:#{repository}`).
        #       to match(/#{message}/)
        #   end

        #   context 'When the user tries to push to that repository' do
        #     before(:context) do
        #       Dir.chdir(@temp_directory) do
        #         system("git init #{repository.split('/').last}")

        #       end
        #     end

        #     it 'there is no local git repository' do
        #       expect(File.exist?(File.join(@temp_directory, 'fixtures'))).
        #         to be(false)
        #     end

        #     it 'the user cannot push to the repository' do
        #       Dir.chdir(File.join(@temp_directory, 'fixtures')) do
        #         file = 'new_file'
        #         `touch #{file}`
        #         `git add #{file}`
        #         `git commit -m "Add #{file}"`
        #         expect(system('git push')).to be(false)
        #       end
        #     end

        #     it 'the user is presented an error message' do
        #       Dir.chdir(File.join(@temp_directory, 'fixtures')) do
        #         expect(`git push`).to match(/#{message}/i)
        #       end
        #     end
        #   end
        # end

        # context 'When a repository is neither readable nor writable' do
        #   let(:repository) { 'cam/my-private-repository' }
        #   include_examples 'no read access or inexistant'
        # end

        # context 'When a repository does not exist' do
        #   let(:repository) { 'my/absent-repository' }
        #   include_examples 'no read access or inexistant'
        # end
      end
    end
  end
end
