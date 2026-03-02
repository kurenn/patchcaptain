module BugsmithRails
  class ExceptionMiddleware
    def initialize(app)
      @app = app
    end

    def call(env)
      @app.call(env)
    rescue StandardError => e
      request = ActionDispatch::Request.new(env)
      Reporter.new.report(e, request: request)
      raise
    end
  end
end
