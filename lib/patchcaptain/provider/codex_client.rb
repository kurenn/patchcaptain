module PatchCaptain
  module Provider
    class CodexClient < BaseClient
      def generate_fix(system_prompt:, user_prompt:)
        uri = URI("#{api_base}/chat/completions")
        response = post_json(
          uri,
          body: {
            model: model,
            messages: [
              { role: "system", content: system_prompt },
              { role: "user", content: user_prompt }
            ],
            temperature: 0.1
          },
          headers: {
            "Authorization" => "Bearer #{api_key}"
          }
        )

        response.dig("choices", 0, "message", "content").to_s
      end
    end
  end
end
