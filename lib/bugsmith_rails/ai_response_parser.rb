module BugsmithRails
  class AIResponseParser
    DEFAULT_RESULT = {
      title: "chore: add bugsmith exception diagnostics",
      body: "Automated Bugsmith report. Manual review required.",
      branch_name: "bugsmith/exception-report",
      commit_message: "chore: add bugsmith exception diagnostics",
      diff: nil
    }.freeze

    def initialize(raw_response)
      @raw_response = raw_response.to_s
    end

    def parse
      data = extract_json
      return DEFAULT_RESULT.merge(title: DEFAULT_RESULT[:title], body: fallback_body) unless data

      {
        title: data["title"].presence || DEFAULT_RESULT[:title],
        body: data["body"].presence || fallback_body,
        branch_name: data["branch_name"].presence || DEFAULT_RESULT[:branch_name],
        commit_message: data["commit_message"].presence || DEFAULT_RESULT[:commit_message],
        diff: data["diff"].presence
      }
    end

    private

    def extract_json
      parse_json(@raw_response) || parse_json(code_block)
    end

    def code_block
      matched = @raw_response.match(/```(?:json)?\s*(\{.*\})\s*```/m)
      matched && matched[1]
    end

    def parse_json(candidate)
      return unless candidate.present?

      JSON.parse(candidate)
    rescue JSON::ParserError
      nil
    end

    def fallback_body
      <<~TEXT.strip
        Bugsmith could not parse structured AI output, so this PR only includes diagnostics.

        Raw AI output:
        #{@raw_response[0, 2000]}
      TEXT
    end
  end
end
