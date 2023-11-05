# frozen_string_literal: true

# name: discourse-chat-bridge
# about: TODO
# version: 0.0.1
# authors: Discourse
# url: TODO
# required_version: 2.7.0

enabled_site_setting :chat_bridge_enabled

module ::ChatBridgeModule
  PLUGIN_NAME = "discourse-chat-bridge"
end

require_relative "app/models/chat_bridge_fake_user"
require_relative "app/models/chat_bridge_telegram_user_info"

after_initialize do
  # Code which should run after Rails has finished booting
  require_relative "lib/chat_bridge_module/engine"
end
