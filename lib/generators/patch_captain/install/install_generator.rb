require "rails/generators"

module PatchCaptain
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      def copy_initializer
        template "patch_captain.rb", "config/initializers/patch_captain.rb"
      end
    end
  end
end
