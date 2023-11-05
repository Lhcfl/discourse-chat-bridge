# frozen_string_literal: true

# name: chat-bridge
# about: TODO
# version: 0.0.1
# authors: Discourse
# url: TODO
# required_version: 2.7.0

enabled_site_setting :chat_bridge_enabled

module ::ChatBridgeModule
  PLUGIN_NAME = "chat-bridge"
end

require_relative "lib/chat_bridge_module/engine"

after_initialize do
  # Code which should run after Rails has finished booting
end
