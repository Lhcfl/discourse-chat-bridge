# frozen_string_literal: true

module ::ChatBridgeModule
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace ChatBridgeModule
    config.autoload_paths << File.join(config.root, "lib")
  end
end
