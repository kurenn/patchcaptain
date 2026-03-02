# BugsmithRails

`bugsmith_rails` captures Rails exceptions and can open a GitHub pull request with an AI-proposed fix.

## 1. Install

In your Rails app `Gemfile`:

```ruby
gem "bugsmith_rails"
```

Then run:

```bash
bundle install
bin/rails generate bugsmith_rails:install
```

## 2. Set API keys

Add these environment variables:

```bash
export CODEX_API_KEY="..."
export ANTHROPIC_API_KEY="..."
export GITHUB_TOKEN="..."
export GITHUB_REPOSITORY="your-org/your-repo"
```

Use either `CODEX_API_KEY` or `ANTHROPIC_API_KEY` based on your provider.

## 3. Configure initializer

Edit `config/initializers/bugsmith_rails.rb`:

```ruby
BugsmithRails.configure do |config|
  config.provider = :codex # or :anthropic

  config.codex_api_key = ENV["CODEX_API_KEY"]
  config.anthropic_api_key = ENV["ANTHROPIC_API_KEY"]

  config.github_token = ENV["GITHUB_TOKEN"]
  config.github_repository = ENV["GITHUB_REPOSITORY"] # "org/repo"
  config.base_branch = "main"

  # Track all exceptions except ignored ones
  config.tracked_exceptions = []
  config.ignored_exceptions = ["ActionController::RoutingError", "ActiveRecord::RecordNotFound"]
end
```

## 4. How it works

When an exception is raised:
1. Bugsmith captures error details and backtrace.
2. Sensitive data is redacted.
3. AI generates a patch proposal.
4. A branch/commit is created.
5. A GitHub PR is opened (if enabled).

## 5. Optional: manual report

```ruby
begin
  # code
rescue => e
  BugsmithRails.notify(e, context: { source: "manual" })
end
```

## Notes

- Review AI-generated PRs before merging.
- Keep keys in secrets manager or Rails encrypted credentials.
- By default, Bugsmith refuses to run if git working tree is dirty.
