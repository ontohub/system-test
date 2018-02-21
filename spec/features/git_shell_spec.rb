# frozen_string_literal: true

# These tests can only run on travis because they need a specially formatted
# ~/.ssh/authorized_keys file as well as an adjusted ssh config.
# Adjusting this on a development machine could break an existing ssh config.
if ENV['TRAVIS']
  # The examples in the sub-contexts need to be run in the defined order.
  # They must not be randomized. This is done to increase the performance.
  # Otherwise, repositories would need to be cloned again and again.
  RSpec.describe 'GitShell' do
    before(:context) do
      @temp_directory = Dir.mktmpdir
      @client_repository = File.join(@temp_directory, 'client')

      @control_repository = File.join(@temp_directory, 'control')

      @file_changed_on_server = 'file_changed_on_server'
      @file_changed_on_client = 'file_changed_on_client'
      @file_changed_on_client_by_force = 'file_changed_on_client_by_force'
    end

    after(:context) do
      FileUtils.rm_rf(@temp_directory)
    end

    context 'When a repository is writable for the user', order: :defined do
      before(:context) do
        @repository = 'ada/fixtures'
      end

      before(:context) do
        rollback_backend
      end

      after(:context) do
        rollback_backend
      end

      before(:context) do
        backend_local_repository = "#{data_dir.join('git', @repository)}.git"
        capture3('git', 'clone', backend_local_repository,
                 @control_repository)
      end

      after(:context) do
        FileUtils.rm_rf(@client_repository)
        FileUtils.rm_rf(@control_repository)
      end

      before(:context) do
        @user = 'ada'
        token = sign_in_api('ada', 'changemenow')['data']['signIn']['jwt']
        save_public_key(token, travis_public_key)
      end

      it 'the user can clone the git repository' do
        Dir.chdir(@temp_directory) do
          _, _, status = capture3('git', 'clone',
                                  "travis@localhost:#{@repository}",
                                  @client_repository)
          expect(status).to be_success
        end
      end

      it 'and there is actually a local git repository' do
        Dir.chdir(@client_repository) do
          _, _, status = capture3('git', 'rev-parse', '--git-dir')
          expect(status).to be_success
        end
      end

      it 'the user can pull server-side changes' do
        Dir.chdir(@control_repository) do
          capture3('touch', @file_changed_on_server)
          capture3('git', 'add', @file_changed_on_server)
          capture3('git', 'commit', '-m', "Add #{@file_changed_on_server}")
          capture3({'SSH_CONNECTION' => 'true'}, 'git', 'push')
        end

        Dir.chdir(@client_repository) do
          _, _, status = capture3('git', 'pull')
          expect(status).to be_success
        end
      end

      it 'the user actually receives the server-side changes' do
        Dir.chdir(@client_repository) do
          expect(File.exist?(@file_changed_on_server)).to be(true)
        end
      end

      it 'the user can push to the repository' do
        Dir.chdir(@client_repository) do
          capture3('touch', @file_changed_on_client)
          capture3('git', 'add', @file_changed_on_client)
          capture3('git', 'commit', '-m', "Add #{@file_changed_on_client}")
          _, _, status = capture3('git', 'push')
          expect(status).to be_success
        end
      end

      it 'and the change is actually on the server' do
        Dir.chdir(@control_repository) do
          capture3({'SSH_CONNECTION' => 'true'}, 'git', 'pull')
          expect(File.exist?(@file_changed_on_client)).to be(true)
        end
      end

      it 'the user cannot force-push to the repository' do
        Dir.chdir(@client_repository) do
          capture3('git', 'commit', '-am', 'Amend the commit', '--amend')
          capture3('touch', @file_changed_on_client_by_force)
          capture3('git', 'add', @file_changed_on_client_by_force)
          capture3('git', 'commit', '-m',
                   "Add #{@file_changed_on_client_by_force}")
          _, _, status = capture3('git', 'push', '--force')
          expect(status).not_to be_success
        end
      end

      it 'the user is presented the correct error message on force-push' do
        message = "Force-pushing (`git push --force') is not permitted"
        Dir.chdir(@client_repository) do
          _, stderr, = Open3.capture3('git', 'push', '--force')
          expect(stderr).to include(message)
        end
      end

      it 'and the change is not on the server' do
        Dir.chdir(@control_repository) do
          capture3({'SSH_CONNECTION' => 'true'}, 'git', 'pull')
          expect(File.exist?(@file_changed_on_client_by_force)).to be(false)
        end
      end
    end

    context 'When a repository is readable but not writable,',
      order: :defined do
      before(:context) do
        @repository = 'bob/my-public-repository'
      end

      before(:context) do
        rollback_backend
      end

      after(:context) do
        rollback_backend
      end

      before(:context) do
        backend_local_repository = "#{data_dir.join('git', @repository)}.git"
        capture3('git', 'clone', backend_local_repository,
                 @control_repository)
      end

      after(:context) do
        FileUtils.rm_rf(@client_repository)
        FileUtils.rm_rf(@control_repository)
      end

      before(:context) do
        @user = 'ada'
        token = sign_in_api('ada', 'changemenow')['data']['signIn']['jwt']
        save_public_key(token, travis_public_key)
      end

      it 'the user can clone the git repository' do
        Dir.chdir(@temp_directory) do
          _, _, status = capture3('git', 'clone',
                                  "travis@localhost:#{@repository}",
                                  @client_repository)
          expect(status).to be_success
        end
      end

      it 'and there is actually a local git repository' do
        Dir.chdir(@client_repository) do
          _, _, status = capture3('git', 'rev-parse', '--git-dir')
          expect(status).to be_success
        end
      end

      it 'the user can pull server-side changes' do
        Dir.chdir(@control_repository) do
          capture3('touch', @file_changed_on_server)
          capture3('git', 'add', @file_changed_on_server)
          capture3('git', 'commit', '-m', "Add #{@file_changed_on_server}")
          capture3({'SSH_CONNECTION' => 'true'}, 'git', 'push')
        end

        Dir.chdir(@client_repository) do
          _, _, status = capture3('git', 'pull')
          expect(status).to be_success
        end
      end

      it 'the user actually receives the server-side changes' do
        Dir.chdir(@client_repository) do
          expect(File.exist?(@file_changed_on_server)).to be(true)
        end
      end

      it 'the user cannot push to the repository' do
        Dir.chdir(@client_repository) do
          capture3('touch', @file_changed_on_client)
          capture3('git', 'add', @file_changed_on_client)
          capture3('git', 'commit', '-m', "Add #{@file_changed_on_client}")
          _, _, status = capture3('git', 'push')
          expect(status).not_to be_success
        end
      end

      it 'the user is presented the correct error message on push' do
        message =
          'Unauthorized: You are unauthorized to write to this repository.'
        Dir.chdir(@client_repository) do
          _, stderr, = capture3('git', 'push')
          expect(stderr).to match(/#{message}/)
        end
      end

      it 'and the change is not on the server' do
        Dir.chdir(@control_repository) do
          capture3({'SSH_CONNECTION' => 'true'}, 'git', 'pull')
          expect(File.exist?(@file_changed_on_client)).to be(false)
        end
      end

      it 'the user cannot force-push to the repository' do
        Dir.chdir(@client_repository) do
          capture3('git', 'commit', '-am', 'Amend the commit', '--amend')
          capture3('touch', @file_changed_on_client_by_force)
          capture3('git', 'add', @file_changed_on_client_by_force)
          capture3('git', 'commit', '-m',
                   "Add #{@file_changed_on_client_by_force}")
          _, _, status = capture3('git', 'push', '--force')
          expect(status).not_to be_success
        end
      end

      it 'the user is presented the correct error message on force-push' do
        message =
          'Unauthorized: You are unauthorized to write to this repository.'
        Dir.chdir(@client_repository) do
          _, stderr, = Open3.capture3('git', 'push', '--force')
          expect(stderr).to include(message)
        end
      end

      it 'and the change is not on the server' do
        Dir.chdir(@control_repository) do
          capture3({'SSH_CONNECTION' => 'true'}, 'git', 'pull')
          expect(File.exist?(@file_changed_on_client_by_force)).to be(false)
        end
      end
    end

    context 'When a repository is neither readable nor writable',
      order: :defined do
      before(:context) do
        @repository = 'cam/my-private-repository'
      end
      # include_examples 'no read access or inexistant'
      let(:message) do
        'The Repository has not been found '\
        'or you are unauthorized to read it.'
      end

      before(:context) do
        rollback_backend
      end

      after(:context) do
        rollback_backend
      end

      before(:context) do
        backend_local_repository = "#{data_dir.join('git', @repository)}.git"
        capture3('git', 'clone', backend_local_repository,
                 @control_repository)
      end

      after(:context) do
        FileUtils.rm_rf(@client_repository)
        FileUtils.rm_rf(@control_repository)
      end

      before(:context) do
        @user = 'ada'
        token = sign_in_api('ada', 'changemenow')['data']['signIn']['jwt']
        save_public_key(token, travis_public_key)
      end

      it 'the user cannot clone the git repository' do
        Dir.chdir(@temp_directory) do
          _, _, status = capture3('git', 'clone',
                                  "travis@localhost:#{@repository}",
                                  @client_repository)
          expect(status).not_to be_success
        end
      end

      it 'the user is presented the correct error message on clone' do
        _, stderr, = capture3('git', 'clone', "localhost:#{@repository}",
                              @client_repository)
        expect(stderr).to match(/#{message}/)
      end

      it 'and there is no local git repository' do
        expect(File.exist?(@client_repository)).to be(false)
      end

      it 'if the repository was cloned before it was deleted or made private, '\
         'the user cannot pull server-side changes' do
        # Setup the clone
        backend_local_repository = "#{data_dir.join('git', @repository)}.git"
        capture3('git', 'clone', backend_local_repository,
                 @client_repository)
        Dir.chdir(@client_repository) do
          config = '.git/config'
          File.write(config, File.read(config).
                       gsub(backend_local_repository,
                            "travis@localhost:#{@repository}"))
        end

        # Make server-side changes
        Dir.chdir(@control_repository) do
          capture3('touch', @file_changed_on_server)
          capture3('git', 'add', @file_changed_on_server)
          capture3('git', 'commit', '-m', "Add #{@file_changed_on_server}")
          capture3({'SSH_CONNECTION' => 'true'}, 'git', 'push')
        end

        # Pull via ssh
        Dir.chdir(@client_repository) do
          _, _, status = capture3('git', 'pull')
          expect(status).not_to be_success
        end
      end

      it 'the user is presented the correct error message on pull' do
        Dir.chdir(@client_repository) do
          _, stderr, = capture3('git', 'pull')
          expect(stderr).to match(/#{message}/)
        end
      end

      it 'the user does not receive the server-side changes' do
        Dir.chdir(@client_repository) do
          expect(File.exist?(@file_changed_on_server)).to be(false)
        end
      end

      it 'the user cannot push to the repository' do
        Dir.chdir(@client_repository) do
          capture3('touch', @file_changed_on_client)
          capture3('git', 'add', @file_changed_on_client)
          capture3('git', 'commit', '-m', "Add #{@file_changed_on_client}")
          _, _, status = capture3('git', 'push')
          expect(status).not_to be_success
        end
      end

      it 'the user is presented the correct error message on push' do
        Dir.chdir(@client_repository) do
          _, stderr, = capture3('git', 'push')
          expect(stderr).to match(/#{message}/)
        end
      end

      it 'and the change is not on the server' do
        Dir.chdir(@control_repository) do
          capture3({'SSH_CONNECTION' => 'true'}, 'git', 'pull')
          expect(File.exist?(@file_changed_on_client)).to be(false)
        end
      end

      it 'the user cannot force-push to the repository' do
        Dir.chdir(@client_repository) do
          capture3('git', 'commit', '-am', 'Amend the commit', '--amend')
          capture3('touch', @file_changed_on_client_by_force)
          capture3('git', 'add', @file_changed_on_client_by_force)
          capture3('git', 'commit', '-m',
                   "Add #{@file_changed_on_client_by_force}")
          _, _, status = capture3('git', 'push', '--force')
          expect(status).not_to be_success
        end
      end

      it 'the user is presented the correct error message on force-push' do
        Dir.chdir(@client_repository) do
          _, stderr, = Open3.capture3('git', 'push', '--force')
          expect(stderr).to include(message)
        end
      end

      it 'and the change is not on the server' do
        Dir.chdir(@control_repository) do
          capture3({'SSH_CONNECTION' => 'true'}, 'git', 'pull')
          expect(File.exist?(@file_changed_on_client_by_force)).to be(false)
        end
      end
    end

    context 'When a repository does not exist', order: :defined do
      before(:context) do
        @repository = 'cam/my-private-repository'
      end
      # include_examples 'no read access or inexistant'
      let(:message) do
        'The Repository has not been found '\
        'or you are unauthorized to read it.'
      end

      before(:context) do
        rollback_backend
      end

      after(:context) do
        rollback_backend
      end

      before(:context) do
        backend_local_repository = "#{data_dir.join('git', @repository)}.git"
        capture3('git', 'clone', backend_local_repository,
                 @control_repository)
      end

      after(:context) do
        FileUtils.rm_rf(@client_repository)
        FileUtils.rm_rf(@control_repository)
      end

      before(:context) do
        @user = 'ada'
        token = sign_in_api('ada', 'changemenow')['data']['signIn']['jwt']
        save_public_key(token, travis_public_key)
      end

      it 'the user cannot clone the git repository' do
        Dir.chdir(@temp_directory) do
          _, _, status = capture3('git', 'clone',
                                  "travis@localhost:#{@repository}",
                                  @client_repository)
          expect(status).not_to be_success
        end
      end

      it 'the user is presented the correct error message on clone' do
        _, stderr, = capture3('git', 'clone', "localhost:#{@repository}",
                              @client_repository)
        expect(stderr).to match(/#{message}/)
      end

      it 'and there is no local git repository' do
        expect(File.exist?(@client_repository)).to be(false)
      end

      it 'if the repository was cloned before it was deleted or made private, '\
         'the user cannot pull server-side changes' do
        # Setup the clone
        backend_local_repository = "#{data_dir.join('git', @repository)}.git"
        capture3('git', 'clone', backend_local_repository,
                @client_repository)
        Dir.chdir(@client_repository) do
          config = '.git/config'
          File.write(config, File.read(config).
                       gsub(backend_local_repository,
                            "travis@localhost:#{@repository}"))
        end

        # Make server-side changes
        Dir.chdir(@control_repository) do
          capture3('touch', @file_changed_on_server)
          capture3('git', 'add', @file_changed_on_server)
          capture3('git', 'commit', '-m', "Add #{@file_changed_on_server}")
          capture3({'SSH_CONNECTION' => 'true'}, 'git', 'push')
        end

        # Pull via ssh
        Dir.chdir(@client_repository) do
          _, _, status = capture3('git', 'pull')
          expect(status).not_to be_success
        end
      end

      it 'the user is presented the correct error message on pull' do
        Dir.chdir(@client_repository) do
          _, stderr, = capture3('git', 'pull')
          expect(stderr).to match(/#{message}/)
        end
      end

      it 'the user does not receive the server-side changes' do
        Dir.chdir(@client_repository) do
          expect(File.exist?(@file_changed_on_server)).to be(false)
        end
      end

      it 'the user cannot push to the repository' do
        Dir.chdir(@client_repository) do
          capture3('touch', @file_changed_on_client)
          capture3('git', 'add', @file_changed_on_client)
          capture3('git', 'commit', '-m', "Add #{@file_changed_on_client}")
          _, _, status = capture3('git', 'push')
          expect(status).not_to be_success
        end
      end

      it 'the user is presented the correct error message on push' do
        Dir.chdir(@client_repository) do
          _, stderr, = capture3('git', 'push')
          expect(stderr).to match(/#{message}/)
        end
      end

      it 'and the change is not on the server' do
        Dir.chdir(@control_repository) do
          capture3({'SSH_CONNECTION' => 'true'}, 'git', 'pull')
          expect(File.exist?(@file_changed_on_client)).to be(false)
        end
      end

      it 'the user cannot force-push to the repository' do
        Dir.chdir(@client_repository) do
          capture3('git', 'commit', '-am', 'Amend the commit', '--amend')
          capture3('touch', @file_changed_on_client_by_force)
          capture3('git', 'add', @file_changed_on_client_by_force)
          capture3('git', 'commit', '-m',
                   "Add #{@file_changed_on_client_by_force}")
          _, _, status = capture3('git', 'push', '--force')
          expect(status).not_to be_success
        end
      end

      it 'the user is presented the correct error message on force-push' do
        Dir.chdir(@client_repository) do
          _, stderr, = Open3.capture3('git', 'push', '--force')
          expect(stderr).to include(message)
        end
      end

      it 'and the change is not on the server' do
        Dir.chdir(@control_repository) do
          capture3({'SSH_CONNECTION' => 'true'}, 'git', 'pull')
          expect(File.exist?(@file_changed_on_client_by_force)).to be(false)
        end
      end
    end
  end
end
