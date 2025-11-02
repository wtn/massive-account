require_relative 'lib/massive/account/version'

Gem::Specification.new do |spec|
  spec.name = 'massive-account'
  spec.version = Massive::Account::VERSION
  spec.authors = ['William T. Nelson']
  spec.email = ['35801+wtn@users.noreply.github.com']

  spec.summary = 'Ruby client for accessing massive.com account details, subscriptions, API keys, and S3 credentials.'
  spec.description = 'A Ruby gem to access your massive.com account details, including subscriptions, API keys, and S3 credentials for flat files.'
  spec.homepage = 'https://github.com/wtn/massive-account'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.2.0'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines(?\x0, chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore test/])
    end
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = %w[lib]

  spec.add_dependency 'base64', '~> 0.2'
end
