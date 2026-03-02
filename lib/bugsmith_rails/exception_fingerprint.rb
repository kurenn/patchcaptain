module BugsmithRails
  class ExceptionFingerprint
    def initialize(payload, release_sha:, repository_path: nil)
      @payload = payload
      @release_sha = release_sha.to_s
      @repository_path = repository_path.to_s
    end

    def value
      Digest::SHA256.hexdigest(
        [
          @release_sha,
          @payload.dig(:exception, :class).to_s,
          normalize_message(@payload.dig(:exception, :message).to_s),
          normalized_first_frame,
          @payload.dig(:request, :method).to_s,
          normalize_path(@payload.dig(:request, :path).to_s)
        ].join("|")
      )
    end

    private

    def normalize_message(message)
      normalized = message.dup
      normalized.gsub!(/[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}/i, "<uuid>")
      normalized.gsub!(/\b0x[0-9a-f]+\b/i, "<hex>")
      normalized.gsub!(/\b\d+\b/, "<num>")
      normalized.strip
    end

    def normalized_first_frame
      frame = Array(@payload.dig(:exception, :backtrace)).find do |line|
        candidate = line.to_s
        next false if candidate.empty?
        next false if candidate.include?("/gems/")

        candidate.include?("/app/") || candidate.start_with?("app/")
      end
      return "" if frame.to_s.empty?

      cleaned = frame.to_s
      cleaned = cleaned.sub(@repository_path, "") unless @repository_path.empty?
      cleaned.gsub(/:\d+/, ":<line>").strip
    end

    def normalize_path(path)
      normalized = path.to_s.dup
      normalized.gsub!(/[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}/i, "<uuid>")
      normalized.gsub!(/\b\d+\b/, "<num>")
      normalized
    end
  end
end
