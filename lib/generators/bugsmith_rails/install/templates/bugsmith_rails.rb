BugsmithRails.configure do |config|
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
  config.github_reports_path = ".bugsmith/reports"
end
