Gem::Specification.new do |spec|
  spec.name          = "plain_errors"
  spec.version       = "0.1.0"
  spec.authors       = ["Your Name"]
  spec.email         = ["your.email@example.com"]

  spec.summary       = "Minimal plaintext error reporting for Rails, optimized for LLMs and coding agents"
  spec.description   = "A Rails middleware inspired by better_errors that provides concise, token-efficient plaintext error output including error messages, stack traces, and code snippets."
  spec.homepage      = "https://github.com/yourusername/plain_errors"
  spec.license       = "MIT"

  spec.required_ruby_version = ">= 2.7.0"

  spec.files = Dir[
    "lib/**/*",
    "README.md",
    "LICENSE",
    "plain_errors.gemspec"
  ]

  spec.require_paths = ["lib"]

  spec.add_dependency "rack", ">= 2.0"

  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rack-test", "~> 2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/yourusername/plain_errors"
  spec.metadata["changelog_uri"] = "https://github.com/yourusername/plain_errors/blob/main/CHANGELOG.md"
end