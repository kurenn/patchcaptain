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
  config.max_backtrace_lines = nil # full backtrace

  # Optional context/skill pack to improve fix quality
  config.skill_path = Rails.root.join(".bugsmith/skills/rails_fix.md").to_s
  # Defaults include:
  # README.md, db/schema.rb, CLAUDE.md, AGENTS.md,
  # .agent/workflows, .claude-on-rails/prompts,
  # .github/copilot-instructions.md, .github/instructions
  # config.context_files = ["README.md", "db/schema.rb"]
end
```

## 4. How it works

When an exception is raised:
1. Bugsmith captures error details and backtrace.
2. Sensitive data is redacted.
3. Bugsmith builds prompt context (skill text + selected project files + backtrace snippets).
4. AI returns concrete `file_changes` (+ optional diff).
5. Bugsmith writes those file changes directly to a GitHub branch via API and opens the PR.
6. The PR also includes a full exception report.

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
- Required token permissions: `Contents (read/write)` and `Pull requests (read/write)`.
