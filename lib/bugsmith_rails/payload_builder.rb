module BugsmithRails
  class PayloadBuilder
    SAFE_HEADERS = %w[
      HTTP_USER_AGENT
      HTTP_ACCEPT
      HTTP_REFERER
      CONTENT_TYPE
      CONTENT_LENGTH
      REQUEST_METHOD
      REQUEST_URI
      PATH_INFO
    ].freeze

    def initialize(exception, request: nil, context: {}, configuration: BugsmithRails.configuration)
      @exception = exception
      @request = request
      @context = context || {}
      @configuration = configuration
      @redactor = Redactor.new(configuration: configuration)
    end

    def build
      payload = {
        occurred_at: Time.now.utc.iso8601,
        rails_env: rails_env,
        ruby_version: RUBY_VERSION,
        rails_version: rails_version,
        exception: exception_payload,
        request: request_payload,
        context: @context
      }.compact

      @redactor.redact(payload)
    end

    private

    def exception_payload
      {
        class: @exception.class.name,
        message: @exception.message.to_s,
        backtrace: Array(@exception.backtrace).first(@configuration.max_backtrace_lines),
        cause: cause_payload
      }.compact
    end

    def cause_payload
      return if @exception.cause.nil?

      {
        class: @exception.cause.class.name,
        message: @exception.cause.message.to_s,
        backtrace: Array(@exception.cause.backtrace).first(20)
      }
    end

    def request_payload
      return unless @request

      {
        method: @request.request_method,
        path: @request.path,
        fullpath: @request.fullpath,
        ip: @request.remote_ip,
        params: filtered_parameters,
        headers: safe_headers,
        request_id: fetch_env("action_dispatch.request_id")
      }.compact
    end

    def filtered_parameters
      if @request.respond_to?(:filtered_parameters)
        @request.filtered_parameters
      elsif @request.respond_to?(:params)
        @request.params
      end
    end

    def safe_headers
      source = @request.env || {}
      SAFE_HEADERS.each_with_object({}) do |header, memo|
        memo[header] = source[header] if source.key?(header)
      end
    end

    def fetch_env(key)
      @request.env[key]
    end

    def rails_env
      return Rails.env if defined?(Rails) && Rails.respond_to?(:env)

      ENV.fetch("RAILS_ENV", ENV.fetch("RACK_ENV", "development"))
    end

    def rails_version
      return Rails.version if defined?(Rails) && Rails.respond_to?(:version)

      nil
    end
  end
end
