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

# global before
$github_ontohub = 'https://github.com/ontohub/'
%w(ontohub-frontend ontohub-backend hets-rabbitmq-wrapper).each do |repo|
  if File.directory?(repo)
    Dir.chdir(repo) do
      # todo: origin/$VAR
      system('git fetch && git reset --hard origin/master')
    end
  else
    system("git clone --depth=1 #{$github_ontohub}#{repo} #{repo}")
  end
end

Dir.chdir('ontohub-backend') do
  # See Bundler Issue https://github.com/bundler/bundler/issue/698 & man page
  # Most output is silenced and only shows errors and warnings
  Bundler.with_clean_env do
    system('bundle install --quiet')
    system('RAILS_ENV=test bundle exec rails db:recreate')
    system('RAILS_ENV=test bundle exec rails db:seed')
    system('psql -d ontohub_test -U postgres -f ../features/support/emaj.sql')
    # Change something in database
    # Waiting for eugenk system('RAILS_ENV=test bundle exec rails repo:clean')
    $backend_pid = fork do
      # exec is needed to kill the process, system & %x & Open3 blocks
      exec('RAILS_ENV=test rails s', out: File::NULL)
    end
  end
  wait_until_listening(3000)
end

Dir.chdir('ontohub-frontend') do
  system('yarn install --pure-lockfile --no-progress')
  system('bower install --silent')
  $frontend_pid = fork do
    # exec is needed to kill the process, system & %x & Open3 blocks
    exec('yarn start', out: File::NULL)
  end
  wait_until_listening(4200)
end

After do
  system(%(psql -d ontohub_test -U postgres -c "SELECT emaj.emaj_rollback_group('system-test', 'EMAJ_LAST_MARK');"))
end

# global after
at_exit do
  kill_process($backend_pid)
  kill_process($frontend_pid)
  Dir.chdir('ontohub-backend') do
    Bundler.with_clean_env do
      system(%(psql -d ontohub_test -U postgres -c "SELECT emaj.emaj_stop_group('system-test');"))
      system('RAILS_ENV=test bundle exec rails db:drop')
    end
  end
end
