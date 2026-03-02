module BugsmithRails
  class Railtie < Rails::Railtie
    initializer "bugsmith_rails.insert_middleware" do |app|
      next unless BugsmithRails.configuration.enabled

      app.middleware.use(ExceptionMiddleware)
    end

    initializer "bugsmith_rails.subscribe_active_job" do
      next unless defined?(ActiveSupport::Notifications)

      ActiveSupport::Notifications.subscribe("perform.active_job") do |*args|
        event = ActiveSupport::Notifications::Event.new(*args)
        exception = event.payload[:exception_object]
        next unless exception

        Reporter.new.report(
          exception,
          context: {
            active_job: {
              job_class: event.payload[:job]&.class&.name
            }
          }
        )
      end
    end
  end
end
