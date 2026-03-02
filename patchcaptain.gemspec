require_relative "lib/patchcaptain/version"

Gem::Specification.new do |spec|
  spec.name = "patchcaptain"
  spec.version = PatchCaptain::VERSION
  spec.authors = ["Abraham Kuri"]
  spec.email = ["abraham@example.com"]

  spec.summary = "Rails-first exception to AI fix PR pipeline"
  spec.description = "Capture Rails exceptions, build trace payloads, ask AI for a patch, and open a GitHub pull request."
  spec.homepage = "https://example.com/patchcaptain"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/changelog"

  spec.files = Dir.glob("lib/**/*") + %w[README.md Rakefile]
  spec.require_paths = ["lib"]

  spec.add_dependency "octokit", ">= 7.2"
  spec.add_dependency "faraday-retry", ">= 2.2"
  spec.add_dependency "rails", ">= 7.0"
end
