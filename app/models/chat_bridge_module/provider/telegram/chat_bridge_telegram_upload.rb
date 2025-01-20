# frozen_string_literal: true

module ::ChatBridgeModule
  module Provider
    module Telegram
      class ChatBridgeTelegramUpload < ActiveRecord::Base
        self.table_name = "chat_bridge_telegram_uploads"

        def self.create_or_update!(**args)
          r = nil
          if (args[:unique_id])
            r = self.find_by(id: args[:unique_id])
          else
            raise "No :unique_id"
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
# Table name: chat_bridge_telegram_uploads
#
#  id        :bigint           not null, primary key
#  upload_id :integer
#  unique_id :string(60)
#
# Indexes
#
#  index_chat_bridge_telegram_uploads_on_unique_id  (unique_id)
#
