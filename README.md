# PatchCaptain

             |\\
            /| \\
           /\_|\_\_\\
        \_\_\_(  ^  )\_\_\_
       /   \\\_===\_/   \\
      /\_\_\_\_\_/\_\_\_\\\_\_\_\_\_\\
         /  /\_\_\_\\  \\
        /\_\_/     \\\_\_\\

`patchcaptain` captures Rails exceptions and can open a GitHub pull request with an AI-proposed fix.

## 1\. Install

In your Rails app `Gemfile`:

```ruby
gem "patchcaptain"
```

Then run:

```bash
bundle install
bin/rails generate patchcaptain:install
```

## 2\. Set API keys

Add these environment variables:

```bash
export CODEX_API_KEY="..."
export ANTHROPIC_API_KEY="..."
export GITHUB_TOKEN="..."
export GITHUB_REPOSITORY="your-org/your-repo"
```

Use either `CODEX_API_KEY` or `ANTHROPIC_API_KEY` based on your provider.

## 3\. Configure initializer

Edit `config/initializers/patchcaptain.rb`:

```ruby
PatchCaptain.configure do |config|
  # Core
  config.enabled = true
  config.provider = :codex # :codex or :anthropic

  # Provider credentials/endpoints
  config.codex_api_key = ENV["CODEX_API_KEY"]
  config.codex_api_base = ENV.fetch("CODEX_API_BASE", "https://api.openai.com/v1")
  config.codex_model = ENV.fetch("CODEX_MODEL", "gpt-5-codex")

  config.anthropic_api_key = ENV["ANTHROPIC_API_KEY"] || ENV["NANTROPIC_API_KEY"]
  config.anthropic_api_base = ENV["ANTHROPIC_API_BASE"] || ENV["NANTROPIC_API_BASE"] || "https://api.anthropic.com"
  config.anthropic_model = ENV["ANTHROPIC_MODEL"] || ENV["NANTROPIC_MODEL"] || "claude-sonnet-4-5"

  # GitHub
  config.github_token = ENV["GITHUB_TOKEN"]
  config.github_repository = ENV["GITHUB_REPOSITORY"] # "org/repo"
  config.base_branch = ENV.fetch("PATCHCAPTAIN_BASE_BRANCH", "main")
  config.github_reports_path = ENV.fetch("PATCHCAPTAIN_REPORTS_PATH", ".patchcaptain/reports")
  config.create_pull_request = true

  # Exception filtering
  # Empty tracked_exceptions => track all except ignored_exceptions
  config.tracked_exceptions = []
  config.ignored_exceptions = ["ActionController::RoutingError", "ActiveRecord::RecordNotFound"]
  # Alternative helper methods:
  # config.track_exceptions(ArgumentError, MyCustomError)
  # config.ignore_exceptions("ActionController::RoutingError")

  # Payload/redaction
  config.max_backtrace_lines = nil # nil => full backtrace
  config.redacted_keys = %w[password token api_key authorization cookie secret session]
  config.redacted_patterns = [
    /Bearer\s+[A-Za-z0-9\-\._~\+\/]+=*/i,
    /ghp_[A-Za-z0-9]{20,}/,
    /sk-[A-Za-z0-9]{20,}/
  ]

  # Prompt context / skills
  config.skill_text = ""
  config.skill_path = ENV["PATCHCAPTAIN_SKILL_PATH"] # optional
  config.context_files = [
    "README.md",
    "db/schema.rb",
    "CLAUDE.md",
    "AGENTS.md",
    ".agent/workflows",
    ".claude-on-rails/prompts",
    ".github/copilot-instructions.md",
    ".github/instructions"
  ]
  config.max_context_files = ENV.fetch("PATCHCAPTAIN_MAX_CONTEXT_FILES", "30").to_i
  config.max_context_file_bytes = ENV.fetch("PATCHCAPTAIN_MAX_CONTEXT_FILE_BYTES", "50000").to_i
  config.max_prompt_context_chars = ENV.fetch("PATCHCAPTAIN_MAX_PROMPT_CONTEXT_CHARS", "20000").to_i
  config.include_backtrace_file_snippets = true
  config.max_backtrace_files = ENV.fetch("PATCHCAPTAIN_MAX_BACKTRACE_FILES", "5").to_i
  config.backtrace_context_radius = ENV.fetch("PATCHCAPTAIN_BACKTRACE_CONTEXT_RADIUS", "20").to_i

  # Runtime behavior
  config.async = true
  config.commit_author_name = "PatchCaptain Rails"
  config.commit_author_email = "patchcaptain@users.noreply.github.com"
  config.logger = Rails.logger

  # Compatibility helpers (kept for older configs)
  config.flow_mode = :github_api # fixed to :github_api
  config.repository_path = Rails.root.to_s # used for context/fingerprint only
  config.require_clean_worktree = false # no-op
end
```

### 3.1 Environment Variables

-   `CODEX_API_KEY`
-   `CODEX_API_BASE` (default: `https://api.openai.com/v1`)
-   `CODEX_MODEL` (default: `gpt-5-codex`)
-   `ANTHROPIC_API_KEY` (or legacy `NANTROPIC_API_KEY`)
-   `ANTHROPIC_API_BASE` (or legacy `NANTROPIC_API_BASE`)
-   `ANTHROPIC_MODEL` (or legacy `NANTROPIC_MODEL`)
-   `GITHUB_TOKEN`
-   `GITHUB_REPOSITORY`
-   `PATCHCAPTAIN_BASE_BRANCH` (default: `main`)
-   `PATCHCAPTAIN_REPORTS_PATH` (default: `.patchcaptain/reports`)
-   `PATCHCAPTAIN_SKILL_PATH` (optional)
-   `PATCHCAPTAIN_MAX_CONTEXT_FILES` (default: `30`)
-   `PATCHCAPTAIN_MAX_CONTEXT_FILE_BYTES` (default: `50000`)
-   `PATCHCAPTAIN_MAX_PROMPT_CONTEXT_CHARS` (default: `20000`)
-   `PATCHCAPTAIN_MAX_BACKTRACE_FILES` (default: `5`)
-   `PATCHCAPTAIN_BACKTRACE_CONTEXT_RADIUS` (default: `20`)
-   `PATCHCAPTAIN_RELEASE_SHA` (optional deploy SHA override for dedupe)
-   `GITHUB_SHA` (fallback release SHA source)

## 4\. How it works

When an exception is raised:

1.  PatchCaptain captures error details and backtrace.
2.  Sensitive data is redacted.
3.  PatchCaptain builds prompt context (skill text + selected project files + backtrace snippets).
4.  AI returns concrete `file_changes` (+ optional diff).
5.  PatchCaptain writes those file changes directly to a GitHub branch via API and opens the PR.
6.  The PR also includes a full exception report.

Duplicate PR protection:

-   PatchCaptain computes a fingerprint using exception data + release SHA.
-   Release SHA is resolved from:
    1.  `PATCHCAPTAIN_RELEASE_SHA`
    2.  `GITHUB_SHA`
    3.  local `git rev-parse HEAD`
-   If an open PR already has the same fingerprint for the same release SHA, PatchCaptain skips creating a new PR.

## 5\. Optional: manual report

```ruby
begin
  # code
rescue => e
  PatchCaptain.notify(e, context: { source: "manual" })
end
```

## Notes

-   Review AI-generated PRs before merging.
-   Keep keys in secrets manager or Rails encrypted credentials.
-   Required token permissions: `Contents (read/write)` and `Pull requests (read/write)`.