module BugsmithRails
  module Provider
    class AnthropicClient < BaseClient
      ANTHROPIC_VERSION = "2023-06-01".freeze

      def generate_fix(system_prompt:, user_prompt:)
        uri = URI("#{api_base}/v1/messages")
        response = post_json(
          uri,
          body: {
            model: model,
            system: system_prompt,
            max_tokens: 4000,
            messages: [
              { role: "user", content: user_prompt }
            ]
          },
          headers: {
            "x-api-key" => api_key,
            "anthropic-version" => ANTHROPIC_VERSION
          }
        )

        segments = response.fetch("content", [])
        text_segment = segments.find { |item| item["type"] == "text" }
        text_segment ? text_segment["text"].to_s : ""
      end
    end
  end
end
