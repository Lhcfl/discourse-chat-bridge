# frozen_string_literal: true

# name: discourse-chat-bridge
# about: Bridge your discourse chat channel to other platform, telegram, etc
# version: 0.0.1
# authors: Lhc_fl
# url: https://github.com/Lhcfl/discourse-chat-bridge
# required_version: 3.0.0

enabled_site_setting :chat_bridge_enabled

module ::ChatBridgeModule
  PLUGIN_NAME = "discourse-chat-bridge"
end

module ::ChatBridgeModule
  module Provider
    module Telegram
      PROVIDER_ID = 1
      PROVIDER_SLUG = "Telegram".freeze
    end
  end
end

require_relative "lib/chat_bridge_module/engine"

after_initialize do
  require_relative "lib/chat_bridge_module/discourse_chat_patches/ghost_user_guardian"

  require_relative "lib/chat_bridge_module/provider/telegram/bridge"
end
