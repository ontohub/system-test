require 'bundler'

def kill_process(pid)
  Process.kill('KILL', pid)
  Process.wait
end

def wait_until_listening(port)
  sleep 0.5 until port_taken?('127.0.0.1', port, 0.5)
end

def port_taken?(ip, port, seconds = 1)
  Timeout::timeout(seconds) do
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
    exts.each { |ext|
      exe = File.join(path, "#{cmd}#{ext}")
      return exe if File.executable?(exe) && !File.directory?(exe)
    }
  end
  return nil
end

def sed
  which('gsed') ? 'gsed' : 'sed'
end

# global before

%w(ontohub-backend hets-rabbitmq-wrapper).each do |repo|
  if File.directory?(repo)
    Dir.chdir(repo) do
      `git fetch && git reset --hard`
      # version has to be a commit
      version = ENV["#{repo.gsub('-', '_').upcase}_VERSION"] || 'origin/master'
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
    system("#{sed} -i \"s#ontohub_test#ontohub_system_test#g\" config/database.yml")
    system('RAILS_ENV=test bundle exec rails db:recreate')
    system('RAILS_ENV=test bundle exec rails db:seed')
    system("psql -d #{$database_name} -U postgres -f ../features/support/emaj.sql")
    # Change something in database
    # Waiting for eugenk system('RAILS_ENV=test bundle exec rails repo:clean')
    $backend_pid = fork do
      # exec is needed to kill the process, system & %x & Open3 blocks
      # We set ONTOHUB_SYSTEM_TEST=true to tell the backend to not skip reading the version from the git repository.
      exec("ONTOHUB_SYSTEM_TEST=true RAILS_ENV=test rails s -p #{$backend_port}", out: File::NULL)
    end
  end
  wait_until_listening($backend_port)
end

Dir.chdir('ontohub-frontend') do
  # Frontend isnt killed properly by after hook
  # system("kill -9 $(lsof -i tcp:#{$frontend_port} -t)")
  system('yarn')
  system("REACT_APP_BACKEND_HOST='#{$backend_port}' yarn build")
  $frontend_pid = fork do
    # exec is needed to kill the process, system & %x & Open3 blocks
    exec("PORT=#{$frontend_port} yarn serve-built", out: File::NULL)
  end
  wait_until_listening($frontend_port)
end

After do |scenario|
  system(%(psql -d #{$database_name} -U postgres -c "SELECT emaj.emaj_rollback_group('system-test', 'EMAJ_LAST_MARK');"))
  Cucumber.wants_to_quit = true if scenario.failed?
end

# global after
at_exit do
  kill_process($backend_pid)
  kill_process($frontend_pid)
  Dir.chdir('ontohub-backend') do
    Bundler.with_clean_env do
      system(%(psql -d #{$database_name} -U postgres -c "SELECT emaj.emaj_stop_group('system-test');"))
      system('RAILS_ENV=test bundle exec rails db:drop')
    end
  end
end
