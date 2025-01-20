# frozen_string_literal: true

module ::ChatBridgeModule
  module Provider
    module Telegram
      class ChatBridgeTelegramUserInfo < ActiveRecord::Base
        self.table_name = "chat_bridge_telegram_user_infos"

        belongs_to :user, class_name: :User, foreign_key: :user_id

        def self.create_or_update!(**args)
          if (args[:user_id])
            r = self.find_by(user_id: args[:user_id])
          elsif (args[:tg_user_id])
            r = self.find_by(tg_user_id: args[:tg_user_id])
          else
            raise "No :user_id or :tg_user_id"
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
# Table name: chat_bridge_telegram_user_infos
#
#  id             :bigint           not null, primary key
#  user_id        :integer
#  tg_user_id     :bigint
#  avatar_file_id :string(60)
#
# Indexes
#
#  index_chat_bridge_telegram_user_infos_on_user_id  (user_id)
#
