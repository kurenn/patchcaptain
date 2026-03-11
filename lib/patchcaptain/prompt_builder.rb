module PatchCaptain
  class PromptBuilder
    def initialize(payload, context_pack: "")
      @payload = payload
      @context_pack = context_pack.to_s
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
          "diff": "string (unified git diff with file paths relative to repository root)",
          "file_changes": [
            {
              "path": "string (repo-relative path)",
              "action": "create|update|delete",
              "content": "string (full final file contents for create/update; empty for delete)"
            }
          ]
        }

        Constraints:
        - Never remove tests; add or adjust tests when possible.
        - Preserve backwards compatibility.
        - Keep changes focused on fixing the reported exception.
        - Prefer minimal edits in existing files.
        - CRITICAL: When action is "update", the "content" field must contain the COMPLETE original file with ONLY your targeted fix applied. You MUST preserve ALL existing code — every method, every route, every line that is not directly related to your fix. Do NOT omit, simplify, or rewrite code that already exists. If a file is provided in the project context, use it as your base and apply only the minimum change needed.
        - CRITICAL: Do NOT replace or rewrite files. Only add or modify the specific lines needed to fix the exception. If a controller already has methods, keep them all. If a routes file has existing routes, keep them all.
        - file_changes must contain concrete edits when you are confident.
        - If you do not have the full contents of a file you need to update, return an empty file_changes array and explain what manual change is needed in "body" instead of guessing the file contents.
        - Do not include markdown fences or prose outside JSON.
      PROMPT
    end

    def to_user_prompt
      prompt = <<~PROMPT
        Exception payload JSON:
        #{JSON.pretty_generate(@payload)}
      PROMPT

      return prompt if @context_pack.strip.empty?

      <<~PROMPT
        #{prompt}

        Additional project context:
        #{@context_pack}
      PROMPT
    end
  end
end
