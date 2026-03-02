module BugsmithRails
  class Configuration
    attr_accessor :enabled,
                  :provider,
                  :codex_api_key,
                  :codex_api_base,
                  :codex_model,
                  :anthropic_api_key,
                  :anthropic_api_base,
                  :anthropic_model,
                  :github_token,
                  :github_repository,
                  :base_branch,
                  :github_reports_path,
                  :skill_text,
                  :skill_path,
                  :context_files,
                  :max_context_files,
                  :max_context_file_bytes,
                  :max_prompt_context_chars,
                  :include_backtrace_file_snippets,
                  :max_backtrace_files,
                  :backtrace_context_radius,
                  :create_pull_request,
                  :async,
                  :tracked_exceptions,
                  :ignored_exceptions,
                  :redacted_keys,
                  :redacted_patterns,
                  :max_backtrace_lines,
                  :commit_author_name,
                  :commit_author_email,
                  :logger

    def initialize
      @enabled = true
      @provider = :codex
      @codex_api_key = ENV["CODEX_API_KEY"]
      @codex_api_base = ENV.fetch("CODEX_API_BASE", "https://api.openai.com/v1")
      @codex_model = ENV.fetch("CODEX_MODEL", "gpt-5-codex")
      @anthropic_api_key = ENV["ANTHROPIC_API_KEY"] || ENV["NANTROPIC_API_KEY"]
      @anthropic_api_base = ENV["ANTHROPIC_API_BASE"] || ENV["NANTROPIC_API_BASE"] || "https://api.anthropic.com"
      @anthropic_model = ENV["ANTHROPIC_MODEL"] || ENV["NANTROPIC_MODEL"] || "claude-sonnet-4-5"
      @github_token = ENV["GITHUB_TOKEN"]
      @github_repository = ENV["GITHUB_REPOSITORY"]
      @base_branch = ENV.fetch("BUGSMITH_BASE_BRANCH", "main")
      @github_reports_path = ENV.fetch("BUGSMITH_REPORTS_PATH", ".bugsmith/reports")
      @repository_path = defined?(Rails) ? Rails.root.to_s : Dir.pwd
      @skill_text = ""
      @skill_path = ENV["BUGSMITH_SKILL_PATH"]
      @context_files = default_context_files
      @max_context_files = ENV.fetch("BUGSMITH_MAX_CONTEXT_FILES", "30").to_i
      @max_context_file_bytes = ENV.fetch("BUGSMITH_MAX_CONTEXT_FILE_BYTES", "50000").to_i
      @max_prompt_context_chars = ENV.fetch("BUGSMITH_MAX_PROMPT_CONTEXT_CHARS", "20000").to_i
      @include_backtrace_file_snippets = true
      @max_backtrace_files = ENV.fetch("BUGSMITH_MAX_BACKTRACE_FILES", "5").to_i
      @backtrace_context_radius = ENV.fetch("BUGSMITH_BACKTRACE_CONTEXT_RADIUS", "20").to_i
      @create_pull_request = true
      @async = true
      @tracked_exceptions = []
      @ignored_exceptions = []
      @redacted_keys = %w[
        password
        passwd
        token
        api_key
        authorization
        cookie
        secret
        session
      ]
      @redacted_patterns = [
        /Bearer\s+[A-Za-z0-9\-\._~\+\/]+=*/i,
        /ghp_[A-Za-z0-9]{20,}/,
        /sk-[A-Za-z0-9]{20,}/
      ]
      @max_backtrace_lines = nil
      @commit_author_name = "Bugsmith Rails"
      @commit_author_email = "bugsmith-rails@users.noreply.github.com"
      @logger = default_logger
    end

    def provider=(value)
      normalized = value.to_s.strip.downcase.to_sym
      @provider = normalized == :nantropic ? :anthropic : normalized
    end

    # Backward-compat aliases for earlier typo'd API names.
    def nantropic_api_key
      anthropic_api_key
    end

    def nantropic_api_key=(value)
      self.anthropic_api_key = value
    end

    def nantropic_api_base
      anthropic_api_base
    end

    def nantropic_api_base=(value)
      self.anthropic_api_base = value
    end

    def nantropic_model
      anthropic_model
    end

    def nantropic_model=(value)
      self.anthropic_model = value
    end

    def track_exceptions(*exceptions)
      @tracked_exceptions |= normalize_exception_list(exceptions)
    end

    def ignore_exceptions(*exceptions)
      @ignored_exceptions |= normalize_exception_list(exceptions)
    end

    # Compatibility shim: flow mode is fixed to :github_api.
    def flow_mode
      :github_api
    end

    def flow_mode=(_value)
      :github_api
    end

    # Compatibility shim; kept for context file discovery.
    def repository_path
      @repository_path
    end

    def repository_path=(value)
      @repository_path = value.to_s
    end

    def require_clean_worktree
      false
    end

    def require_clean_worktree=(_value); end

    private

    def default_logger
      if defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
        Rails.logger
      else
        Logger.new($stdout)
      end
    end

    def normalize_exception_list(exceptions)
      exceptions.flatten.compact.map do |entry|
        entry.is_a?(Class) ? entry.name : entry.to_s
      end.uniq
    end

    def default_context_files
      [
        "README.md",
        "db/schema.rb",
        "CLAUDE.md",
        "AGENTS.md",
        ".agent/workflows",
        ".claude-on-rails/prompts",
        ".github/copilot-instructions.md",
        ".github/instructions"
      ]
    end
  end
end
