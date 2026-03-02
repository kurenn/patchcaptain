require_relative "test_helper"

class ExceptionFingerprintTest < Minitest::Test
  def test_same_logical_exception_has_same_fingerprint_with_dynamic_numbers
    payload_a = {
      exception: {
        class: "NoMethodError",
        message: "undefined method `name' for #<User:0x0000000100ab1234 id: 123>",
        backtrace: ["/app/models/user.rb:41:in `decorate'"]
      },
      request: { method: "GET", path: "/users/123" }
    }
    payload_b = {
      exception: {
        class: "NoMethodError",
        message: "undefined method `name' for #<User:0x0000000100ff9999 id: 456>",
        backtrace: ["/app/models/user.rb:88:in `decorate'"]
      },
      request: { method: "GET", path: "/users/789" }
    }

    fingerprint_a = BugsmithRails::ExceptionFingerprint.new(payload_a, release_sha: "abc123").value
    fingerprint_b = BugsmithRails::ExceptionFingerprint.new(payload_b, release_sha: "abc123").value

    refute_equal "", fingerprint_a
    refute_equal "", fingerprint_b
    assert_equal fingerprint_a, fingerprint_b
  end

  def test_release_sha_changes_fingerprint
    payload = {
      exception: {
        class: "RuntimeError",
        message: "boom 123",
        backtrace: ["/app/services/payment.rb:10:in `call'"]
      },
      request: { method: "POST", path: "/payments" }
    }
    f1 = BugsmithRails::ExceptionFingerprint.new(payload, release_sha: "sha-one").value
    f2 = BugsmithRails::ExceptionFingerprint.new(payload, release_sha: "sha-two").value
    refute_equal f1, f2
  end
end
