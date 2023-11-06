# frozen_string_literal: true

class CreateChatBridgeFakeUser < ActiveRecord::Migration[7.0]
  def change
    create_table :chat_bridge_fake_users do |t|
      t.integer :user_id
      t.integer :provider_id
      t.bigint :external_user_id, index: true
      t.string :external_username, limit: 100, index: true
    end
  end
end
