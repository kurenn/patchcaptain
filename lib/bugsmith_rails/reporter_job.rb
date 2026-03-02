module BugsmithRails
  class ReporterJob
    if defined?(ActiveJob::Base)
      class Async < ActiveJob::Base
        queue_as :default

        def perform(payload)
          FixOrchestrator.new(payload).call
        end
      end

      def self.perform_later(payload)
        Async.perform_later(payload)
      end
    else
      def self.perform_later(payload)
        new.perform(payload)
      end

      def perform(payload)
        FixOrchestrator.new(payload).call
      end
    end
  end
end
