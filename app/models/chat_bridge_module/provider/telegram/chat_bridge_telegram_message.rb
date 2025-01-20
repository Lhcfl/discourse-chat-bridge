# frozen_string_literal: true

module ::ChatBridgeModule
  module Provider
    module Telegram
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

# == Schema Information
#
# Table name: chat_bridge_telegram_messages
#
#  id          :bigint           not null, primary key
#  message_id  :bigint
#  chat_id     :bigint
#  user_id     :integer
#  tg_user_id  :bigint
#  tg_chat_id  :bigint
#  tg_msg_id   :bigint
#  raw         :text
#  other_infos :text
#
# Indexes
#
#  index_chat_bridge_telegram_messages_on_message_id  (message_id)
#  index_chat_bridge_telegram_messages_on_tg_msg_id   (tg_msg_id)
#
