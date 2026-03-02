require "rails/generators"

module BugsmithRails
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      def copy_initializer
        template "bugsmith_rails.rb", "config/initializers/bugsmith_rails.rb"
      end
    end
  end
end
