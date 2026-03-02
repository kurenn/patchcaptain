require "json"
require "logger"
require "net/http"
require "digest"
require "open3"
require "pathname"
require "securerandom"
require "time"
require "uri"

require "active_support/core_ext/hash"
require "active_support/core_ext/object/blank"
require "active_support/json"

require "patchcaptain/version"
require "patchcaptain/configuration"
require "patchcaptain/exception_filter"
require "patchcaptain/redactor"
require "patchcaptain/payload_builder"
require "patchcaptain/reporter"
require "patchcaptain/reporter_job"
require "patchcaptain/exception_middleware"
require "patchcaptain/ai_response_parser"
require "patchcaptain/context_pack_builder"
require "patchcaptain/exception_fingerprint"
require "patchcaptain/prompt_builder"
require "patchcaptain/provider/base_client"
require "patchcaptain/provider/codex_client"
require "patchcaptain/provider/anthropic_client"
require "patchcaptain/provider/nantropic_client"
require "patchcaptain/github_client"
require "patchcaptain/fix_orchestrator"
require "patchcaptain/railtie" if defined?(Rails::Railtie)

module PatchCaptain
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
