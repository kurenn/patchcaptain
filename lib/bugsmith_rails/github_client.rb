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

    def find_open_pull_request_by_markers(release_sha:, fingerprint:)
      page = 1
      loop do
        pulls = @client.pull_requests(@repository, state: "open", per_page: 100, page: page)
        break if pulls.empty?

        matched = pulls.find do |pr|
          body = pr[:body].to_s
          body.include?("bugsmith_release_sha: #{release_sha}") &&
            body.include?("bugsmith_fingerprint: #{fingerprint}")
        end
        return matched if matched

        page += 1
      end
      nil
    end

    def pull_request_url(pull_request)
      return pull_request[:html_url] if pull_request.is_a?(Hash)

      nil
    end

    def create_branch(base:, requested_branch:)
      branch = sanitize_branch_name(requested_branch)
      resolved_base = resolve_base_branch(base)
      sha = @client.branch(@repository, resolved_base).commit.sha

      5.times do
        begin
          @client.create_ref(@repository, "heads/#{branch}", sha)
          return { branch: branch, base_branch: resolved_base }
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

    def delete_file(branch:, path:, commit_message:)
      existing = @client.contents(@repository, path: path, ref: branch)
      @client.delete_contents(@repository, path, commit_message, existing.sha, branch: branch)
    rescue Octokit::NotFound
      nil
    end

    private

    def resolve_base_branch(base)
      @client.branch(@repository, base)
      base
    rescue Octokit::NotFound
      repo = begin
        @client.repository(@repository)
      rescue Octokit::Unauthorized, Octokit::Forbidden
        raise BugsmithRails::Error, "GitHub token does not have access to #{@repository.inspect}"
      rescue Octokit::NotFound => e
        raise BugsmithRails::Error, "Repository #{@repository.inspect} not found or token has no access (#{e.message})"
      end

      default_branch = repo.default_branch.to_s
      return default_branch if default_branch.present?

      raise BugsmithRails::Error, "Could not resolve a base branch for #{@repository.inspect}"
    rescue Octokit::Unauthorized, Octokit::Forbidden
      raise BugsmithRails::Error, "GitHub token does not have access to #{@repository.inspect}"
    end

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
