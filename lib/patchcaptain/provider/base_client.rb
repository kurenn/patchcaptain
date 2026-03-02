module PatchCaptain
  module Provider
    class BaseClient
      attr_reader :api_key, :api_base, :model

      def initialize(api_key:, api_base:, model:)
        @api_key = api_key
        @api_base = api_base
        @model = model
      end

      private

      def post_json(uri, body:, headers:)
        request = Net::HTTP::Post.new(uri)
        headers.each { |key, value| request[key] = value }
        request["Content-Type"] = "application/json"
        request.body = JSON.dump(body)

        response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
          http.read_timeout = 60
          http.open_timeout = 15
          http.request(request)
        end

        unless response.is_a?(Net::HTTPSuccess)
          raise PatchCaptain::Error, "Provider request failed (#{response.code}): #{response.body}"
        end

        JSON.parse(response.body)
      end
    end
  end
end
