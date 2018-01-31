# frozen_string_literal: true

require 'bundler'
require 'pry'

REPOS_DIRECTORY = 'repositories'

def kill_process(pid)
  Process.kill('TERM', pid)
  Process.wait
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

def which(cmd)
  exts = ENV['PATHEXT'] ? ENV['PATHEXT'].split(';') : ['']
  ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
    exts.each do |ext|
      exe = File.join(path, "#{cmd}#{ext}")
      return exe if File.executable?(exe) && !File.directory?(exe)
    end
  end

  nil
end

def sed
  which('gsed') ? 'gsed' : 'sed'
end

# global before

%w(ontohub-backend ontohub-frontend hets-agent).each do |repo|
  if File.directory?(File.join(REPOS_DIRECTORY, repo))
    Dir.chdir(File.join(REPOS_DIRECTORY, repo)) do
      `git fetch && git reset --hard`
    end
  else
    system("git clone #{$github_ontohub}#{repo} " +
           File.join(REPOS_DIRECTORY, repo))
  end
  Dir.chdir(File.join(REPOS_DIRECTORY, repo)) do
    # version has to be a commit
    version = ENV["#{repo.tr('-', '_').upcase}_VERSION"] || 'origin/master'
    puts "Checking out #{repo} at #{version}"
    unless system("git checkout #{version} 1> /dev/null 2> /dev/null")
      raise "Can't checkout #{repo} version #{version}"
    end
  end
end

%w(ontohub-backend hets-agent).each do |repo|
  Dir.chdir(File.join(REPOS_DIRECTORY, repo)) do
    settings_yml = <<~YML
    rabbitmq:
      prefix: ontohub_system_test
      exchange: ontohub_system_test
    YML
    File.write('config/settings.local.yml', settings_yml)
  end
end

Dir.chdir(File.join(REPOS_DIRECTORY, 'ontohub-backend')) do
  # See Bundler Issue https://github.com/bundler/bundler/issue/698 & man page
  # Most output is silenced and only shows errors and warnings
  Bundler.with_clean_env do
    system('bundle install --quiet')
    system('echo before:')
    system('cat config/database.yml')
    system("#{sed} -i \"s#ontohub_development#ontohub_system_test#g\" "\
           'config/database.yml')
    system('echo after:')
    system('cat config/database.yml')
    system('bundle exec rails db:recreate:seed')
    $data_backup_dir = Dir.mktmpdir
    system("cp -r data #{$data_backup_dir}/")
    system("psql --no-psqlrc -d #{$database_name} -U postgres "\
           '-f ../../features/support/emaj.sql 1> /dev/null 2> /dev/null')
    # Change something in database
    # Waiting for eugenk system('RAILS_ENV=test bundle exec rails repo:clean')
    $backend_pid = fork do
      # exec is needed to kill the process, system & %x & Open3 blocks
      # We set ONTOHUB_SYSTEM_TEST=true to tell the backend to not skip reading
      # the version from the git repository.
      exec({'ONTOHUB_SYSTEM_TEST' => 'true'}, 'bundle exec rails server -p ' +
           $backend_port.to_s, out: File::NULL)
    end
    $sneakers_pid = fork do
      exec('bundle exec rails sneakers:run', out: File::NULL)
    end
  end
  wait_until_listening($backend_port)
end

Dir.chdir(File.join(REPOS_DIRECTORY, 'ontohub-frontend')) do
  # Frontend isnt killed properly by after hook
  # system("kill -9 $(lsof -i tcp:#{$frontend_port} -t)")
  system('yarn --no-progress --silent')
  system("REACT_APP_BACKEND_HOST='http://localhost:#{$backend_port}' "\
         'yarn build --no-progress --silent')
  $frontend_pid = fork do
    # exec is needed to kill the process, system & %x & Open3 blocks
    exec("PORT=#{$frontend_port} node_modules/serve/bin/serve.js build "\
         '-p $PORT', out: File::NULL)
  end
  wait_until_listening($frontend_port)
end

After do
  sql_command =
    "SELECT emaj.emaj_rollback_group('system-test', 'EMAJ_LAST_MARK');"
  system(%(psql --no-psqlrc -d #{$database_name} -U postgres) +
         %( -c "#{sql_command}" 1> /dev/null 2> /dev/null))
  Dir.chdir(File.join(REPOS_DIRECTORY, 'ontohub-backend')) do
    system('rm -rf data')
    system("cp -r #{$data_backup_dir}/data .")
  end
  visit('/')
  page.execute_script 'localStorage.clear()'
end

# global after
at_exit do
  Thread.new { kill_process($backend_pid) }
  Thread.new { kill_process($frontend_pid) }
  Thread.new { kill_process($sneakers_pid) }
  Thread.new do
    # After a grace period, send TERM to the sneakers process again to finally
    # terminate it and its children.
    sleep 10
    kill_process($sneakers_pid)
  end
  Thread.list.each { |thread| thread.join if thread != Thread.current }
  Dir.chdir(File.join(REPOS_DIRECTORY, 'ontohub-backend')) do
    Bundler.with_clean_env do
      system(%(psql --no-psqlrc -d #{$database_name} -U postgres -c ) +
             %("SELECT emaj.emaj_stop_group('system-test');" ) +
             %(1> /dev/null))
      system('bundle exec rails db:drop')
    end
  end
  FileUtils.rm_rf($data_backup_dir)
end
