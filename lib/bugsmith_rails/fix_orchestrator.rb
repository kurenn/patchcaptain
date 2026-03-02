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
      run_github_api_flow(plan, raw_response)
    rescue => e
      @configuration.logger.error("[BugsmithRails] orchestration failed: #{e.class}: #{e.message}")
    end

    private

    def run_github_api_flow(plan, raw_response)
      return unless @configuration.create_pull_request

      branch = github_client.create_branch(
        base: @configuration.base_branch,
        requested_branch: plan[:branch_name]
      )
      report_path, report_content = remote_report_file(raw_response, plan[:diff])
      github_client.upsert_file(
        branch: branch,
        path: report_path,
        content: report_content,
        commit_message: plan[:commit_message]
      )

      pr_body = +"#{plan[:body]}\n\n"
      pr_body << "### Bugsmith Exception Summary\n"
      pr_body << "- Exception: `#{@payload.dig(:exception, :class)}`\n"
      pr_body << "- Message: `#{@payload.dig(:exception, :message).to_s.gsub('`', "'")}`\n"
      pr_body << "- Report file: `#{report_path}`\n"
      pr_body << "- Proposed diff present: #{plan[:diff].present? ? 'yes' : 'no'}\n"
      if plan[:diff].present?
        pr_body << "\n```diff\n#{plan[:diff][0, 6000]}\n```\n"
      end

      pr_url = github_client.create_pull_request(
        title: plan[:title],
        body: pr_body,
        head: branch,
        base: @configuration.base_branch
      )
      @configuration.logger.info("[BugsmithRails] Opened PR via GitHub API: #{pr_url}")
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

    def remote_report_file(raw_response, diff)
      timestamp = Time.now.utc.strftime("%Y%m%d%H%M%S")
      path = File.join(@configuration.github_reports_path, "#{timestamp}.md")
      content = <<~REPORT
        # Bugsmith Exception Report

        ## Metadata
        - generated_at: #{Time.now.utc.iso8601}
        - flow_mode: #{@configuration.flow_mode}
        - provider: #{@configuration.provider}

        ## Exception Payload
        ```json
        #{JSON.pretty_generate(@payload)}
        ```

        ## AI Raw Response
        ```
        #{raw_response}
        ```

        ## Proposed Diff
        ```diff
        #{diff.to_s}
        ```
      REPORT
      [path, content]
    end
  end
end
