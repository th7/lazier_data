# frozen_string_literal: true

require_relative 'lib/lazier_data/version'

Gem::Specification.new do |spec|
  spec.name = 'lazier_data'
  spec.version = LazierData::VERSION
  spec.authors = ['Tyler Hartland']
  spec.email = ['tylerhartland7@gmail.com']

  spec.summary = 'The incredible productivity of massive laziness.'
  spec.description = <<~DESCRIPTION
    Allows setting up data processing that works intuitively, but behind the secenes processes lazily.
  DESCRIPTION
  spec.homepage = 'https://github.com/th7/lazier_data'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.1.0'

  spec.metadata['allowed_push_host'] = 'https://rubygems.org'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/th7/lazier_data'
  # spec.metadata['changelog_uri'] = "TODO: Put your gem's CHANGELOG.md URL here."
  spec.metadata['rubygems_mfa_required'] = 'true'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"
end
