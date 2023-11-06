# frozen_string_literal: true

class CreateChatBridgeTelegramUploads < ActiveRecord::Migration[7.0]
  def change
    create_table :chat_bridge_telegram_uploads do |t|
      t.integer :upload_id
      t.string :unique_id, limit: 60, index: true
    end
  end
end
