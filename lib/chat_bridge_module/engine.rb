# frozen_string_literal: true

module ::ChatBridgeModule
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace ChatBridgeModule
    config.autoload_paths << File.join(config.root, "lib")
  end
end

require_relative "discourse_chat_patches/ghost_user_guardian"
require_relative "provider/telegram/telegram_bridge"
require_relative "provider/matrix/matrix_bridge"
