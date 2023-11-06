# frozen_string_literal: true

module ::ChatBridgeModule
  module Provider
    module TelegramBridge
      class ChatBridgeTelegramMessage < ActiveRecord::Base
        self.table_name = "chat_bridge_telegram_messages"

        belongs_to :user, class_name: :User, foreign_key: :user_id
        belongs_to :discourse_message, class_name: "Chat::Message", foreign_key: :message_id

        def self.create_or_update!(**args)
          r = nil
          if (args[:tg_chat_id].present? && args[:tg_msg_id].present?)
            r = self.find_by(tg_msg_id: args[:tg_msg_id], tg_chat_id: args[:tg_chat_id])
          else
            raise "No :tg_chat_id and :tg_msg_id provided"
          end

          return r if r.present?
          self.create!(**args)
        end
      end
    end
  end
end
