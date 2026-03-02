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

    def create_branch(base:, requested_branch:)
      branch = sanitize_branch_name(requested_branch)
      sha = @client.branch(@repository, base).commit.sha

      5.times do
        begin
          @client.create_ref(@repository, "heads/#{branch}", sha)
          return branch
        rescue Octokit::UnprocessableEntity => e
          raise unless branch_exists_error?(e)

          branch = "#{branch}-#{SecureRandom.hex(3)}"
        end
      end

      raise BugsmithRails::Error, "Could not create a unique GitHub branch for Bugsmith PR"
    end

    def upsert_file(branch:, path:, content:, commit_message:)
      existing = @client.contents(@repository, path: path, ref: branch)
      @client.update_contents(@repository, path, commit_message, existing.sha, content, branch: branch)
    rescue Octokit::NotFound
      @client.create_contents(@repository, path, commit_message, content, branch: branch)
    end

    private

    def sanitize_branch_name(name)
      raw = name.to_s.downcase.gsub(/[^a-z0-9\/_-]/, "-").gsub(%r{/+}, "/").gsub(/-{2,}/, "-")
      cleaned = raw.gsub(/\A[-\/]+|[-\/]+\z/, "")
      candidate = cleaned.presence || "bugsmith/exception-fix-#{SecureRandom.hex(4)}"
      candidate.start_with?("bugsmith/") ? candidate : "bugsmith/#{candidate}"
    end

    def branch_exists_error?(error)
      error.message.to_s.include?("Reference already exists")
    end
  end
end
