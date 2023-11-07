# frozen_string_literal: true

class CreateChatBridgeTelegramMessages < ActiveRecord::Migration[7.0]
  def change
    create_table :chat_bridge_telegram_messages do |t|
      t.bigint :message_id, index: true
      t.bigint :chat_id
      t.integer :user_id
      t.bigint :tg_user_id
      t.bigint :tg_chat_id
      t.bigint :tg_msg_id, index: true
      t.text :raw
      t.text :other_infos
    end
  end
end
