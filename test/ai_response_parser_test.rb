require_relative "test_helper"

class AIResponseParserTest < Minitest::Test
  def test_parses_file_changes
    raw = <<~JSON
      {
        "title": "fix: nil user crash",
        "body": "Fixes nil access",
        "branch_name": "bugsmith/fix-nil",
        "commit_message": "fix: handle nil user",
        "diff": "",
        "file_changes": [
          {"path":"app/controllers/users_controller.rb","action":"update","content":"class UsersController; end"},
          {"path":"tmp/nope","action":"delete","content":""}
        ]
      }
    JSON

    parsed = BugsmithRails::AIResponseParser.new(raw).parse
    assert_equal "fix: nil user crash", parsed[:title]
    assert_equal 2, parsed[:file_changes].size
    assert_equal :update, parsed[:file_changes].first[:action]
  end

  def test_fallback_has_empty_file_changes
    parsed = BugsmithRails::AIResponseParser.new("invalid json").parse
    assert_equal [], parsed[:file_changes]
  end
end
