module BugsmithRails
  class Redactor
    FILTERED_VALUE = "[FILTERED]".freeze

    def initialize(configuration: BugsmithRails.configuration)
      @configuration = configuration
    end

    def redact(object)
      case object
      when Hash
        redact_hash(object)
      when Array
        object.map { |item| redact(item) }
      when String
        redact_string(object)
      else
        object
      end
    end

    private

    def redact_hash(hash)
      hash.each_with_object({}) do |(key, value), memo|
        memo[key] = sensitive_key?(key) ? FILTERED_VALUE : redact(value)
      end
    end

    def redact_string(text)
      @configuration.redacted_patterns.reduce(text.dup) do |memo, pattern|
        memo.gsub(pattern, FILTERED_VALUE)
      end
    end

    def sensitive_key?(key)
      normalized = key.to_s.downcase
      @configuration.redacted_keys.any? { |item| normalized.include?(item.downcase) }
    end
  end
end
