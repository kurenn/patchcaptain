module PatchCaptain
  class ExceptionFilter
    def initialize(configuration: PatchCaptain.configuration)
      @configuration = configuration
    end

    def track?(exception)
      return false if ignored?(exception)
      return true if @configuration.tracked_exceptions.empty?

      matches?(@configuration.tracked_exceptions, exception)
    end

    private

    def ignored?(exception)
      matches?(@configuration.ignored_exceptions, exception)
    end

    def matches?(collection, exception)
      collection.any? do |entry|
        exception.is_a?(resolve_exception(entry))
      end
    end

    def resolve_exception(entry)
      case entry
      when Class
        entry
      else
        Object.const_get(entry.to_s)
      end
    rescue NameError
      UnknownTrackedException
    end

    class UnknownTrackedException < StandardError; end
  end
end
