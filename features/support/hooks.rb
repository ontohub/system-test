# frozen_string_literal: true

require 'bundler'
require 'pry'

def kill_process(pid)
  Process.kill('KILL', pid)
  Process.wait
end

def wait_until_listening(port)
  sleep 0.5 until port_taken?('127.0.0.1', port, 0.5)
end

def port_taken?(ip, port, seconds = 1)
  Timeout.timeout(seconds) do
    begin
      TCPSocket.new(ip, port).close
      true
    rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
      false
    end
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
  if File.directory?(repo)
    Dir.chdir(repo) do
      `git fetch && git reset --hard`
      # version has to be a commit
      version = ENV["#{repo.tr('-', '_').upcase}_VERSION"] || 'origin/master'
      unless system("git checkout #{version}")
        raise "Can't checkout #{repo} version #{version}"
      end
    end
  else
    system("git clone #{$github_ontohub}#{repo} #{repo}")
  end
end

Dir.chdir('ontohub-backend') do
  # See Bundler Issue https://github.com/bundler/bundler/issue/698 & man page
  # Most output is silenced and only shows errors and warnings
  Bundler.with_clean_env do
    system('bundle install --quiet')
    system("#{sed} -i \"s#ontohub_test#ontohub_system_test#g\" "\
           'config/database.yml')
    system('RAILS_ENV=test bundle exec rails db:recreate')
    system('RAILS_ENV=test bundle exec rails db:seed')
    $data_backup_dir = Dir.mktmpdir
    system("cp -r data #{$data_backup_dir}/")
    system("psql -d #{$database_name} -U postgres "\
           '-f ../features/support/emaj.sql')
    # Change something in database
    # Waiting for eugenk system('RAILS_ENV=test bundle exec rails repo:clean')
    $backend_pid = fork do
      # exec is needed to kill the process, system & %x & Open3 blocks
      # We set ONTOHUB_SYSTEM_TEST=true to tell the backend to not skip reading
      # the version from the git repository.
      exec("bundle exec rails server -p #{$backend_port}", out: File::NULL)
    end
    $sneakers_pid = fork do
      exec('bundle exec rails sneakers:run', out: File::NULL)
    end
  end
  wait_until_listening($backend_port)
end

Dir.chdir('ontohub-frontend') do
  # Frontend isnt killed properly by after hook
  # system("kill -9 $(lsof -i tcp:#{$frontend_port} -t)")
  system('yarn')
  system("REACT_APP_BACKEND_HOST='http://localhost:#{$backend_port}' "\
         'yarn build')
  $frontend_pid = fork do
    # exec is needed to kill the process, system & %x & Open3 blocks
    exec("PORT=#{$frontend_port} node_modules/serve/bin/serve.js build "\
         '-p $PORT', out: File::NULL)
  end
  wait_until_listening($frontend_port)
end

After do
  system(%(psql -d #{$database_name} -U postgres -c ) +
         %("SELECT emaj.emaj_rollback_group('system-test', 'EMAJ_LAST_MARK');"))
  Dir.chdir('ontohub-backend') do
    system("cp -r #{$data_backup_dir}/data .")
  end
  visit('/')
  page.execute_script 'localStorage.clear()'
end

# global after
at_exit do
  kill_process($backend_pid)
  kill_process($frontend_pid)
  kill_process($sneakers_pid)
  Dir.chdir('ontohub-backend') do
    Bundler.with_clean_env do
      system(%(psql -d #{$database_name} -U postgres -c ) +
             %("SELECT emaj.emaj_stop_group('system-test');"))
      system('RAILS_ENV=test bundle exec rails db:drop')
    end
  end
  FileUtils.rm_rf($data_backup_dir)
end
