require "bridgetown"

Bridgetown.load_tasks

# Run rake without specifying any command to execute a deploy build by default.
task default: :deploy

desc "Build the Bridgetown site for deployment"
task :deploy => [:clean] do
  Bridgetown::Commands::Build.start
end

desc "Build the site in a test environment"
task :test do
  ENV["BRIDGETOWN_ENV"] = "test"
  Bridgetown::Commands::Build.start
end

require "minitest/test_task"
Minitest::TestTask.create(:test) do |t| # adds onto the test task: build first, then run tests
  t.libs << "test" << "plugins"
  t.warning = false
end

Dir.glob("lib/tasks/*.rake").each { |r| load r }

desc "Runs the clean command"
task :clean do
  Bridgetown::Commands::Clean.start
end
