require 'bundler/setup'
require 'bundler/gem_tasks'
require 'minitest/test_task'
require 'yard'

Minitest::TestTask.create

YARD::Rake::YardocTask.new(:doc) do |t|
  t.files = ['lib/**/*.rb']
  t.options = ['--no-private']
end

task default: :test
