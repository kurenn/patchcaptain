module BugsmithRails
  class Reporter
    def initialize(configuration: BugsmithRails.configuration)
      @configuration = configuration
      @filter = ExceptionFilter.new(configuration: configuration)
    end

    def report(exception, request: nil, context: {})
      return unless @configuration.enabled
      return unless @filter.track?(exception)

      payload = PayloadBuilder.new(
        exception,
        request: request,
        context: context,
        configuration: @configuration
      ).build

      if @configuration.async
        ReporterJob.perform_later(payload)
      else
        FixOrchestrator.new(payload, configuration: @configuration).call
      end
    rescue => e
      @configuration.logger.error("[BugsmithRails] report failed: #{e.class}: #{e.message}")
    end
  end
end
