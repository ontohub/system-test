# frozen_string_literal: true

# rubocop:disable Metrics/AbcSize
# rubocop:disable Metrics/MethodLength
# rubocop:disable Metrics/ModuleLength
# rubocop:disable Style/GlobalVars
module Applications
  # rubocop:enable Metrics/ModuleLength
  REPOSITORY_ROOT = Pathname.new(__FILE__).join('../../../repositories')

  GITHUB_ONTOHUB = 'https://github.com/ontohub/'
  FRONTEND_PORT = 3002
  BACKEND_PORT = 3003
  DATABASE_NAME = 'ontohub_system_test'

  DATA_DIR = Pathname.new(__FILE__).join('../../../tmp/data')
  DATA_BACKUP_DIR = Dir.mktmpdir

  ENVIRONMENT = {
    'ONTOHUB_SYSTEM_TEST' => 'true',
    'DISABLE_CAPTCHA' => 'true',
    'RAILS_ENV' => 'production',
    'HETS_AGENT_ENV' => 'production',
  }.freeze
  ENVIRONMENT_PREFIX = ENVIRONMENT.map { |k, v| %(#{k}="#{v}") }.join(' ')

  module InstanceMethods
    def rollback
      rollback_backend
      rollback_frontend
    end

    def rollback_backend
      # Rollback the database
      sql_command =
        "SELECT emaj.emaj_rollback_group('system-test', 'EMAJ_LAST_MARK');"
      system(%(psql --no-psqlrc -d #{DATABASE_NAME} -U postgres) +
             %( -c "#{sql_command}" 1> /dev/null 2> /dev/null))
      # Rollback the data directory
      DATA_DIR.rmtree
      system(%(cp -r "#{DATA_BACKUP_DIR}/data" "#{DATA_DIR.dirname}"))
    end

    def rollback_frontend
      visit('/')
      page.execute_script 'localStorage.clear()'
    end

    def backend_url
      "http://localhost:#{BACKEND_PORT}"
    end

    def frontend_url
      "http://localhost:#{FRONTEND_PORT}"
    end

    def database_name
      DATABASE_NAME
    end

    def repository_root
      REPOSITORY_ROOT
    end

    def data_dir
      DATA_DIR
    end
  end

  class << self
    def kill_process(pid)
      Process.kill('TERM', pid)
      Process.wait
      # rubocop:disable Lint/HandleExceptions
    rescue Errno::ESRCH
      # rubocop:enable Lint/HandleExceptions
      # It has already terminated
    end

    def wait_until_listening(port)
      sleep 0.5 until port_taken?('127.0.0.1', port, 0.5)
    end

    def port_taken?(ip, port, seconds = 1)
      Timeout.timeout(seconds) do
        TCPSocket.new(ip, port).close
        true
      rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
        false
      end
    rescue Timeout::Error
      false
    end

    def file_inreplace(file, search, replace)
      File.write(file, File.read(file).gsub(search, replace))
    end

    def setup_and_start_applications
      checkout_proper_versions
      configure_applications
      setup_backend_and_indexer
      setup_bundler
      setup_frontend
      seed
      start_backend
      start_hets_agent
      start_indexer
      start_frontend
    end

    def checkout_proper_versions
      %w(ontohub-backend ontohub-frontend hets-agent indexer git-shell).
        each do |repo|
        repo_directory = REPOSITORY_ROOT.join(repo)
        if repo_directory.directory?
          Dir.chdir(repo_directory.to_s) do
            Open3.capture3('git', 'fetch')
            Open3.capture3('git', 'reset', '--hard')
          end
        else
          Open3.capture3('git', 'clone', "#{GITHUB_ONTOHUB}#{repo}",
                         repo_directory)
        end

        silenced = ' 1> /dev/null 2> /dev/null'
        Dir.chdir(repo_directory.to_s) do
          # version has to be a commit
          version =
            ENV["#{repo.tr('-', '_').upcase}_VERSION"] || 'origin/master'
          $stdout.puts "Checking out #{repo} at #{version}"
          unless system("git checkout #{version}#{silenced}")
            raise "Can't checkout #{repo} version #{version}"
          end
          version_is_branch =
            system("git show-ref refs/heads/#{version}#{silenced}")
          `git reset --hard origin/#{version}` if version_is_branch
          $stdout.puts("Using #{repo} revision #{`git log -1 --format=%H`}")
        end
      end
    end

    def configure_applications
      %w(ontohub-backend hets-agent indexer git-shell).each do |repo|
        repo_directory = REPOSITORY_ROOT.join(repo)
        Dir.chdir(repo_directory.to_s) do
          settings_yml = <<~YML
            data_directory: #{DATA_DIR}
            git_shell:
              path: ../git-shell/bin/git-shell-travis.sh
              copy_authorized_keys_executable: bin/copy_authorized_keys#{ENV['TRAVIS'] ? '_travis' : ''}
            rabbitmq:
              virtual_host: ontohub_system_test
            backend:
              url: http://localhost:#{BACKEND_PORT}
            hets:
              path: #{`which hets`}
          YML
          File.write('config/settings.local.yml', settings_yml)
        end
      end
    end

    def setup_backend_and_indexer
      %w(ontohub-backend indexer).each do |repo|
        Dir.chdir(REPOSITORY_ROOT.join(repo).to_s) do
          # See Bundler Issue https://github.com/bundler/bundler/issue/698 & man
          # page.
          Bundler.with_clean_env do
            # Adjust the databse
            file_inreplace('config/database.yml',
                           /database: .*$/,
                           "database: #{DATABASE_NAME}")
          end
        end
      end

      Dir.chdir(REPOSITORY_ROOT.join('ontohub-backend')) do
        # Use the development secrets in the production environment
        secrets_file = 'config/secrets.yml'
        unless File.read(secrets_file).lines.last.start_with?('# PREPARED')
          file_inreplace(secrets_file, /^development:/, '_______')
          file_inreplace(secrets_file, /^production:/, 'development:')
          file_inreplace(secrets_file, /^_______/, 'production:')
          File.write(secrets_file, "#{File.read(secrets_file)}\n# PREPARED")
        end
      end
    end

    def setup_bundler
      $stdout.puts 'Installing the bundles...'
      %w(ontohub-backend hets-agent indexer git-shell).each do |repo|
        $stdout.puts "#{repo}: bundle install..."
        Dir.chdir(REPOSITORY_ROOT.join(repo).to_s) do
          # See Bundler Issue https://github.com/bundler/bundler/issue/698 & man
          # page.
          Bundler.with_clean_env do
            # Install dependencies
            system('bundle install --quiet')
          end
        end
      end
    end

    def seed
      begin
        DATA_DIR.rmtree
        # rubocop:disable Lint/HandleExceptions
      rescue Errno::ENOENT
        # rubocop:enable Lint/HandleExceptions
        # We just want to have a clean state. The directory is created in the
        # next step.
      end
      DATA_DIR.mkpath
      Dir.chdir(REPOSITORY_ROOT.join('ontohub-backend').to_s) do
        # See Bundler Issue https://github.com/bundler/bundler/issue/698 & man
        # page.
        Bundler.with_clean_env do
          # Create seed data
          system("#{ENVIRONMENT_PREFIX} bundle exec rails db:recreate:seed")
          # Snapshot seeded data
          system(%(cp -r "#{DATA_DIR}" "#{DATA_BACKUP_DIR}/"))
        end
      end
      system("psql --no-psqlrc -d #{DATABASE_NAME} -U postgres "\
             '-f spec/support/emaj.sql 1> /dev/null 2> /dev/null')
    end

    def start_backend
      Dir.chdir(REPOSITORY_ROOT.join('ontohub-backend').to_s) do
        Bundler.with_clean_env do
          $backend_pid = fork do
            # exec is needed to kill the process, system & %x & Open3 blocks.
            # We set ONTOHUB_SYSTEM_TEST=true to tell the backend to not skip
            # reading the version from the git repository.
            exec(ENVIRONMENT,
                 "bundle exec rails server -p #{BACKEND_PORT}",
                 out: File::NULL)
          end
        end
        Bundler.with_clean_env do
          $sneakers_pid = fork do
            exec(ENVIRONMENT, 'bundle exec rails sneakers:run', out: File::NULL)
          end
        end
        wait_until_listening(BACKEND_PORT)
      end
    end

    def start_hets_agent
      Dir.chdir(REPOSITORY_ROOT.join('hets-agent').to_s) do
        Bundler.with_clean_env do
          $hets_agent_pid = fork do
            exec(ENVIRONMENT, 'bin/hets_agent', out: File::NULL)
          end
        end
      end
    end

    def start_indexer
      Dir.chdir(REPOSITORY_ROOT.join('indexer').to_s) do
        Bundler.with_clean_env do
          $indexer_pid = fork do
            exec(ENVIRONMENT, 'bin/indexer', out: File::NULL)
          end
        end
      end
    end

    def setup_frontend
      Dir.chdir(REPOSITORY_ROOT.join('ontohub-frontend').to_s) do
        # Frontend isnt killed properly by after hook
        # system("kill -9 $(lsof -i tcp:#{FRONTEND_PORT} -t)")
        system('yarn --no-progress --silent')
        system("REACT_APP_BACKEND_HOST=http://localhost:#{BACKEND_PORT} "\
               'yarn build --no-progress --silent')
      end
    end

    def start_frontend
      Dir.chdir(REPOSITORY_ROOT.join('ontohub-frontend').to_s) do
        $frontend_pid = fork do
          # exec is needed to kill the process, system & %x & Open3 blocks
          exec("PORT=#{FRONTEND_PORT} node_modules/serve/bin/serve.js build "\
               '-p $PORT', out: File::NULL)
        end
        wait_until_listening(FRONTEND_PORT)
      end
    end

    def stop_applications
      Thread.new { kill_process($backend_pid) }
      Thread.new { kill_process($sneakers_pid) }
      Thread.new { kill_process($hets_agent_pid) }
      Thread.new { kill_process($indexer_pid) }
      Thread.new { kill_process($frontend_pid) }
      Thread.list.each { |thread| thread.join if thread != Thread.current }
      Dir.chdir(REPOSITORY_ROOT.join('ontohub-backend').to_s) do
        Bundler.with_clean_env do
          system(%(psql --no-psqlrc -d #{DATABASE_NAME} -U postgres -c ) +
                 %("SELECT emaj.emaj_stop_group('system-test');" ) +
                 %(1> /dev/null))
          system('RAILS_ENV=production bundle exec rails db:drop')
        end
      end
      FileUtils.rm_rf(DATA_BACKUP_DIR)
    end
  end
end

RSpec.configure do |config|
  config.before(:suite) do
    Applications.setup_and_start_applications
  end

  config.after(:suite) do
    Applications.stop_applications
  end

  config.include Applications::InstanceMethods

  config.after(:context, type: :rollback) do
    Applications.rollback
  end
end
# rubocop:enable Metrics/AbcSize
# rubocop:enable Metrics/MethodLength
# rubocop:enable Style/GlobalVars
