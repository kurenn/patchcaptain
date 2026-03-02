require_relative "test_helper"

class RedactorTest < Minitest::Test
  def setup
    @config = PatchCaptain::Configuration.new
    @redactor = PatchCaptain::Redactor.new(configuration: @config)
  end

  def test_redacts_sensitive_keys
    source = { "password" => "123456", "safe" => "ok" }
    result = @redactor.redact(source)
    assert_equal "[FILTERED]", result["password"]
    assert_equal "ok", result["safe"]
  end

  def test_redacts_sensitive_token_patterns
    source = { "log" => "Authorization: Bearer sk-ABCDEF12345678901234567890" }
    result = @redactor.redact(source)
    assert_includes result["log"], "[FILTERED]"
  end
end
