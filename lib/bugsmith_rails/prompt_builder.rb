module BugsmithRails
  class PromptBuilder
    def initialize(payload)
      @payload = payload
    end

    def to_system_prompt
      <<~PROMPT
        You are a senior Rails engineer. Analyze the exception payload and propose a safe, minimal bug fix.

        Return ONLY valid JSON with this exact schema:
        {
          "title": "string (PR title)",
          "body": "string (markdown summary and rationale)",
          "branch_name": "string (short git branch, lowercase, slash allowed)",
          "commit_message": "string",
          "diff": "string (unified git diff with file paths relative to repository root)"
        }

        Constraints:
        - Never remove tests; add or adjust tests when possible.
        - Preserve backwards compatibility.
        - Keep the diff focused on fixing the reported exception.
        - If unsure, return an empty string for "diff" and explain uncertainty in "body".
      PROMPT
    end

    def to_user_prompt
      <<~PROMPT
        Exception payload JSON:
        #{JSON.pretty_generate(@payload)}
      PROMPT
    end
  end
end
