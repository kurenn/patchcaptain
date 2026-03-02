require "rails/generators"

module PatchCaptain
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      def copy_initializer
        template "patchcaptain.rb", "config/initializers/patchcaptain.rb"
      end
    end
  end
end
