Before do
  $github_ontohub = 'https://github.com/ontohub/'
  %w(ontohub-frontend ontohub-backend hets-rabbitmq-wrapper).each do |repo|
    if File.directory?(repo)
      Dir.chdir(repo) do
        system('git pull')
      end
    else
      system("git clone --depth=1 #{$github_ontohub}#{repo} #{repo}")
    end
  end

  Dir.chdir('ontohub-backend') do
    system('bundle install')
    system('bundle exec rails db:create')
    system('bundle exec rails db:seed')
    fork do
      system('rails s')
    end
    system('sleep 15')
  end
end
