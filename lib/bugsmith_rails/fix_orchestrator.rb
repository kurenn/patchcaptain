module BugsmithRails
  class FixOrchestrator
    def initialize(payload, configuration: BugsmithRails.configuration)
      @payload = payload
      @configuration = configuration
    end

    def call
      validate_setup!
      prompt = PromptBuilder.new(@payload)
      raw_response = provider_client.generate_fix(
        system_prompt: prompt.to_system_prompt,
        user_prompt: prompt.to_user_prompt
      )
      plan = AIResponseParser.new(raw_response).parse

      git = GitRepository.new(
        path: @configuration.repository_path,
        base_branch: @configuration.base_branch,
        logger: @configuration.logger,
        require_clean_worktree: @configuration.require_clean_worktree
      )

      branch = git.prepare_branch(plan[:branch_name])
      apply_diff_or_report(git, plan[:diff], raw_response)
      git.stage_all

      committed = git.commit(
        message: plan[:commit_message],
        author_name: @configuration.commit_author_name,
        author_email: @configuration.commit_author_email
      )
      return unless committed

      git.push(branch)
      return unless @configuration.create_pull_request

      pr_url = github_client.create_pull_request(
        title: plan[:title],
        body: plan[:body],
        head: branch,
        base: @configuration.base_branch
      )
      @configuration.logger.info("[BugsmithRails] Opened PR: #{pr_url}")
    rescue => e
      @configuration.logger.error("[BugsmithRails] orchestration failed: #{e.class}: #{e.message}")
    end

    private

    def apply_diff_or_report(git, diff, raw_response)
      if diff.present?
        git.apply_diff(diff)
      else
        git.write_report(payload: @payload, raw_response: raw_response)
      end
    rescue
      git.write_report(payload: @payload, raw_response: raw_response)
    end

    def provider_client
      case @configuration.provider
      when :codex
        Provider::CodexClient.new(
          api_key: @configuration.codex_api_key,
          api_base: @configuration.codex_api_base,
          model: @configuration.codex_model
        )
      when :anthropic, :nantropic
        Provider::AnthropicClient.new(
          api_key: @configuration.anthropic_api_key,
          api_base: @configuration.anthropic_api_base,
          model: @configuration.anthropic_model
        )
      else
        raise BugsmithRails::Error, "Unsupported provider: #{@configuration.provider}"
      end
    end

    def github_client
      GithubClient.new(
        token: @configuration.github_token,
        repository: @configuration.github_repository
      )
    end

    def validate_setup!
      if @configuration.create_pull_request
        raise BugsmithRails::Error, "github_token is missing" if @configuration.github_token.blank?
        raise BugsmithRails::Error, "github_repository is missing" if @configuration.github_repository.blank?
      end

      case @configuration.provider
      when :codex
        raise BugsmithRails::Error, "codex_api_key is missing" if @configuration.codex_api_key.blank?
      when :anthropic, :nantropic
        raise BugsmithRails::Error, "anthropic_api_key is missing" if @configuration.anthropic_api_key.blank?
      end
    end
  end
end
