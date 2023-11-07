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

require_relative "app/models/chat_bridge_fake_user"
require_relative "app/models/chat_bridge_telegram_user_info"
require_relative "app/models/chat_bridge_telegram_message"
require_relative "app/models/chat_bridge_telegram_upload"

after_initialize do
  # Code which should run after Rails has finished booting
  require_relative "lib/chat_bridge_module/engine"
end
