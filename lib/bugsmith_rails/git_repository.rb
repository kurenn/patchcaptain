module BugsmithRails
  class GitRepository
    attr_reader :path

    def initialize(path:, base_branch:, logger:, require_clean_worktree: true)
      @path = Pathname(path)
      @base_branch = base_branch
      @logger = logger
      @require_clean_worktree = require_clean_worktree
    end

    def prepare_branch(name)
      ensure_clean_worktree! if @require_clean_worktree
      branch = unique_branch_name(sanitize_branch_name(name))
      run_git("checkout", @base_branch)
      run_git("checkout", "-b", branch)
      branch
    end

    def apply_diff(diff)
      return if diff.to_s.strip.empty?

      Tempfile.create(["bugsmith_patch", ".diff"]) do |file|
        file.write(diff)
        file.flush
        run_git("apply", "--3way", file.path)
      end
    end

    def write_report(payload:, raw_response:)
      timestamp = Time.now.utc.strftime("%Y%m%d%H%M%S")
      filename = @path.join("tmp", "bugsmith_reports", "#{timestamp}.md")
      FileUtils.mkdir_p(filename.dirname)
      File.write(
        filename,
        <<~REPORT
          # Bugsmith Diagnostic Report

          ## Exception Payload
          ```json
          #{JSON.pretty_generate(payload)}
          ```

          ## AI Raw Response
          ```
          #{raw_response}
          ```
        REPORT
      )

      filename.relative_path_from(@path).to_s
    end

    def stage_all
      run_git("add", "-A")
    end

    def commit(message:, author_name:, author_email:)
      return unless staged_changes?

      run_git("commit", "-m", message.to_s, "--author", "#{author_name} <#{author_email}>")
      true
    end

    def push(branch)
      run_git("push", "-u", "origin", branch)
    end

    private

    def staged_changes?
      _stdout, _stderr, status = Open3.capture3("git", "diff", "--cached", "--quiet", chdir: path.to_s)
      !status.success?
    end

    def sanitize_branch_name(name)
      raw = name.to_s.downcase.gsub(/[^a-z0-9\/_-]/, "-").gsub(%r{/+}, "/").gsub(/-{2,}/, "-")
      cleaned = raw.gsub(/\A[-\/]+|[-\/]+\z/, "")
      candidate = cleaned.presence || "bugsmith/exception-fix-#{SecureRandom.hex(4)}"
      candidate.start_with?("bugsmith/") ? candidate : "bugsmith/#{candidate}"
    end

    def unique_branch_name(branch)
      return branch unless branch_exists?(branch)

      "#{branch}-#{SecureRandom.hex(3)}"
    end

    def branch_exists?(branch)
      _stdout, _stderr, status = Open3.capture3(
        "git",
        "rev-parse",
        "--verify",
        "--quiet",
        "refs/heads/#{branch}",
        chdir: path.to_s
      )
      status.success?
    end

    def ensure_clean_worktree!
      stdout, _stderr, status = Open3.capture3("git", "status", "--porcelain", chdir: path.to_s)
      return if status.success? && stdout.strip.empty?

      raise BugsmithRails::Error, "Repository has uncommitted changes. Refusing to run Bugsmith fix flow."
    end

    def run_git(*args)
      stdout, stderr, status = Open3.capture3("git", *args, chdir: path.to_s)
      return stdout.strip if status.success?

      raise BugsmithRails::Error, "git #{args.join(' ')} failed: #{stderr.strip}"
    end
  end
end
