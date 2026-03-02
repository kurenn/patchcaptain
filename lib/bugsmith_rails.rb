require "json"
require "logger"
require "net/http"
require "open3"
require "pathname"
require "securerandom"
require "fileutils"
require "tempfile"
require "time"
require "uri"

require "active_support/core_ext/hash"
require "active_support/core_ext/object/blank"
require "active_support/json"

require "bugsmith_rails/version"
require "bugsmith_rails/configuration"
require "bugsmith_rails/exception_filter"
require "bugsmith_rails/redactor"
require "bugsmith_rails/payload_builder"
require "bugsmith_rails/reporter"
require "bugsmith_rails/reporter_job"
require "bugsmith_rails/exception_middleware"
require "bugsmith_rails/ai_response_parser"
require "bugsmith_rails/prompt_builder"
require "bugsmith_rails/provider/base_client"
require "bugsmith_rails/provider/codex_client"
require "bugsmith_rails/provider/anthropic_client"
require "bugsmith_rails/provider/nantropic_client"
require "bugsmith_rails/git_repository"
require "bugsmith_rails/github_client"
require "bugsmith_rails/fix_orchestrator"
require "bugsmith_rails/railtie" if defined?(Rails::Railtie)

module BugsmithRails
  class Error < StandardError; end

  class << self
    def configure
      yield(configuration)
    end

    def configuration
      @configuration ||= Configuration.new
    end

    def reset!
      @configuration = Configuration.new
    end

    def notify(exception, context: {})
      Reporter.new.report(exception, context: context)
    end

    def logger
      configuration.logger
    end
  end
end
