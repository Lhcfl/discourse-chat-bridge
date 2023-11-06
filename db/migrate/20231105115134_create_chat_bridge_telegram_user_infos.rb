# frozen_string_literal: true

class CreateChatBridgeTelegramUserInfos < ActiveRecord::Migration[7.0]
  def change
    create_table :chat_bridge_telegram_user_infos do |t|
      t.integer :user_id, index: true
      t.bigint :tg_user_id
      t.string :avatar_file_id, limit: 60
    end
  end
end
