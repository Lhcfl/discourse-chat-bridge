# frozen_string_literal: true

module ::ChatBridgeModule
  # should follow: plugins/chat/app/services/chat/create_message.rb
  class GhostUserGuardian < ::Guardian
    def can_join_chat_channel?(*)
      true
    end

    def can_create_channel_message?(*)
      true
    end

    def can_create_direct_message?(*)
      true
    end
  end
end
