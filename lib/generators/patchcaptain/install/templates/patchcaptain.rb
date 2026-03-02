PatchCaptain.configure do |config|
  # AI provider:
  #   :codex or :anthropic
  config.provider = :codex

  # API keys (prefer Rails encrypted credentials in production).
  config.codex_api_key = ENV["CODEX_API_KEY"]
  config.anthropic_api_key = ENV["ANTHROPIC_API_KEY"]

  # Provider models (optional).
  # config.codex_model = "gpt-5-codex"
  # config.anthropic_model = "claude-sonnet-4-5"

  # GitHub integration.
  config.github_token = ENV["GITHUB_TOKEN"]
  config.github_repository = ENV["GITHUB_REPOSITORY"] # e.g. "acme/my_rails_app"
  config.base_branch = "main"

  # Scope of exception tracking.
  # Empty tracked_exceptions means "track all except ignored".
  config.tracked_exceptions = []
  config.ignored_exceptions = [
    "ActionController::RoutingError",
    "ActiveRecord::RecordNotFound"
  ]

  # Safety and behavior.
  config.async = true
  config.max_backtrace_lines = nil # nil means full backtrace
  config.github_reports_path = ".patchcaptain/reports"

  # Optional "skill" and context to improve AI fixes.
  # config.skill_path = Rails.root.join(".patchcaptain/skills/rails_fix.md").to_s
  # config.skill_text = "Team coding rules..."
  # Default context_files includes:
  # README.md, db/schema.rb, CLAUDE.md, AGENTS.md,
  # .agent/workflows, .claude-on-rails/prompts,
  # .github/copilot-instructions.md, .github/instructions
  # config.context_files = ["README.md", "db/schema.rb", ".github/instructions"]
  # config.max_context_files = 30
  # config.max_context_file_bytes = 50_000
  # config.max_prompt_context_chars = 20_000
  # config.include_backtrace_file_snippets = true
  # config.max_backtrace_files = 5
  # config.backtrace_context_radius = 20

  # Optional deploy SHA override for dedupe keys.
  # By default PatchCaptain uses PATCHCAPTAIN_RELEASE_SHA, then GITHUB_SHA,
  # then local `git rev-parse HEAD`.
  # ENV["PATCHCAPTAIN_RELEASE_SHA"] ||= "abc123"
end
