module BugsmithRails
  class FixOrchestrator
    def initialize(payload, configuration: BugsmithRails.configuration)
      @payload = payload
      @configuration = configuration
    end

    def call
      validate_setup!
      context_pack = ContextPackBuilder.new(@payload, configuration: @configuration).build
      prompt = PromptBuilder.new(@payload, context_pack: context_pack)
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

      release_sha = resolved_release_sha
      fingerprint = ExceptionFingerprint.new(
        @payload,
        release_sha: release_sha,
        repository_path: @configuration.repository_path
      ).value

      existing_pr = github_client.find_open_pull_request_by_markers(
        release_sha: release_sha,
        fingerprint: fingerprint
      )
      if existing_pr
        url = github_client.pull_request_url(existing_pr)
        @configuration.logger.info("[BugsmithRails] Skipping duplicate PR for release=#{release_sha}, fingerprint=#{fingerprint}. Existing PR: #{url}")
        return
      end

      branch_info = github_client.create_branch(
        base: @configuration.base_branch,
        requested_branch: plan[:branch_name]
      )
      branch = branch_info.fetch(:branch)
      base_branch = branch_info.fetch(:base_branch)
      applied_changes = apply_file_changes(branch, plan[:file_changes], plan[:commit_message])
      report_path, report_content = remote_report_file(
        raw_response,
        plan[:diff],
        plan[:file_changes],
        release_sha: release_sha,
        fingerprint: fingerprint
      )
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
      pr_body << "- Applied file changes: #{applied_changes}\n"
      pr_body << "- Proposed diff present: #{plan[:diff].present? ? 'yes' : 'no'}\n"
      pr_body << "- Release SHA: `#{release_sha}`\n"
      pr_body << "- Fingerprint: `#{fingerprint}`\n"
      if plan[:diff].present?
        pr_body << "\n```diff\n#{plan[:diff][0, 6000]}\n```\n"
      end
      pr_body << "\n<!-- bugsmith_release_sha: #{release_sha} -->\n"
      pr_body << "<!-- bugsmith_fingerprint: #{fingerprint} -->\n"

      pr_url = github_client.create_pull_request(
        title: plan[:title],
        body: pr_body,
        head: branch,
        base: base_branch
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

    def remote_report_file(raw_response, diff, file_changes, release_sha:, fingerprint:)
      timestamp = Time.now.utc.strftime("%Y%m%d%H%M%S")
      path = File.join(@configuration.github_reports_path, "#{timestamp}.md")
      file_change_summary = Array(file_changes).map do |change|
        "- #{change[:action]} #{change[:path]}"
      end.join("\n")
      file_change_summary = "- none" if file_change_summary.empty?
      content = <<~REPORT
        # Bugsmith Exception Report

        ## Metadata
        - generated_at: #{Time.now.utc.iso8601}
        - flow_mode: #{@configuration.flow_mode}
        - provider: #{@configuration.provider}
        - release_sha: #{release_sha}
        - fingerprint: #{fingerprint}

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

        ## Parsed File Changes
        #{file_change_summary}
      REPORT
      [path, content]
    end

    def apply_file_changes(branch, file_changes, commit_message)
      valid_changes = sanitize_file_changes(file_changes)
      valid_changes.each do |change|
        path = change.fetch(:path)
        action = change.fetch(:action)
        message = "#{commit_message} (#{action} #{path})"

        case action
        when :delete
          github_client.delete_file(branch: branch, path: path, commit_message: message)
        when :create, :update
          github_client.upsert_file(
            branch: branch,
            path: path,
            content: change.fetch(:content),
            commit_message: message
          )
        end
      end
      valid_changes.length
    end

    def sanitize_file_changes(file_changes)
      Array(file_changes).filter_map do |change|
        next unless change.is_a?(Hash)

        path = change[:path].to_s.tr("\\", "/").strip
        action = change[:action].to_sym
        content = change[:content].to_s
        next if path.empty?
        next unless %i[create update delete].include?(action)
        next unless safe_repo_relative_path?(path)

        {
          path: path,
          action: action,
          content: action == :delete ? "" : content
        }
      rescue
        nil
      end
    end

    def safe_repo_relative_path?(path)
      path_name = Pathname(path)
      return false if path_name.absolute?

      clean = path_name.cleanpath.to_s
      return false if clean.start_with?("../") || clean == ".."
      return false if clean.start_with?(".git/")

      true
    end

    def resolved_release_sha
      env_sha = ENV["BUGSMITH_RELEASE_SHA"].presence || ENV["GITHUB_SHA"].presence
      return env_sha.to_s if env_sha

      stdout, _stderr, status = Open3.capture3("git", "rev-parse", "HEAD", chdir: @configuration.repository_path.to_s)
      return stdout.to_s.strip if status.success? && stdout.to_s.strip.present?

      "unknown-release"
    rescue
      "unknown-release"
    end
  end
end
