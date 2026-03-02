require "octokit"

module BugsmithRails
  class GithubClient
    def initialize(token:, repository:)
      @client = Octokit::Client.new(access_token: token)
      @repository = repository
    end

    def create_pull_request(title:, body:, head:, base:)
      response = @client.create_pull_request(@repository, base, head, title, body)
      response.fetch(:html_url)
    end
  end
end
