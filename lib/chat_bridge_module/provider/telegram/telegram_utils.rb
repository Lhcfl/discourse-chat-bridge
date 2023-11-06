# frozen_string_literal: true

module ::ChatBridgeModule
  module Provider
    module TelegramBridge
      def self.update_name_and_username_from_tg(user, message)
        name = message["from"]["first_name"]
        begin
          name = "#{name} #{message["from"]["last_name"]}" if message["from"]["last_name"]
          name = "[Telegram] #{name}"
          if user.name != name
            user.name = name
            user.save!
          end
        rescue => exception
          Rails.logger.warn(
            "[Telegram Bridge] Failed to update tg name \"#{name}\" for user @#{user.username}: #{exception}",
          )
        end

        name = message["from"]["first_name"]
        begin
          name = message["from"]["username"] if message["from"]["username"]
          name = "#{name}.tg"
          if user.username != name
            user.username = name
            user.save!
          end
        rescue => exception
          Rails.logger.warn(
            "[Telegram Bridge] Failed to update tg username \"#{name}\" for user @#{user.username}: #{exception}",
          )
        end
      end

      def self.update_avatar_from_tg(user, message, channel_id, force = false)
        bot = ::ChatBridgeModule::Provider::TelegramBridge::TelegramBot.new(channel_id)

        response =
          bot._request("getUserProfilePhotos", { user_id: message["from"]["id"], limit: 1 })

        puts "Got response:"
        puts response

        if response["ok"] && response["result"].present? && response["result"]["photos"].present? &&
             response["result"]["photos"][0].present? &&
             response["result"]["photos"][0][0]["file_id"].present? &&
             response["result"]["photos"][0][0]["file_unique_id"].present?
          if !force &&
               ChatBridgeTelegramUserInfo.find_by(
                 tg_user_id: message["from"]["id"],
               )&.avatar_file_id == response["result"]["photos"][0][0]["file_unique_id"]
            return "Don't need update"
          end

          puts "Get File id: #{response["result"]["photos"][0][0]["file_id"]}"

          bot.get_upload_from_file(
            user:,
            file: response["result"]["photos"][0][0],
            type: "avatar",
            filename: "avatar_tg_user#{user.id}",
          ) do |upload|
            user.update!(uploaded_avatar_id: upload.id)

            ::ChatBridgeModule::Provider::TelegramBridge::ChatBridgeTelegramUserInfo.create_or_update!(
              user_id: user.id,
              tg_user_id: message["from"]["id"],
              avatar_file_id: response["result"]["photos"][0][0]["file_unique_id"],
            )
          end
        end
      end

      def self.update_user_profile_from_tg(user, message, channel_id)
        Scheduler::Defer.later("Telegram Bridge Update User Profile") do
          update_name_and_username_from_tg(user, message)
          update_avatar_from_tg(user, message, channel_id)
        end
      end
    end
  end
end
