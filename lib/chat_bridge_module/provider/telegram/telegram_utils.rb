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
            user.name = "[Telegram] #{name}"
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
             response["result"]["photos"][0][0]["file_id"].present?
          if !force &&
               ChatBridgeTelegramUserInfo.find_by(
                 tg_user_id: message["from"]["id"],
               )&.avatar_file_id == response["result"]["photos"][0][0]["file_id"]
            return "Don't need update"
          end

          puts "Get File id: #{response["result"]["photos"][0][0]["file_id"]}"

          file_path_res =
            bot._request("getFile", { file_id: response["result"]["photos"][0][0]["file_id"] })

          if file_path_res["ok"] && file_path_res["result"] && file_path_res["result"]["file_path"]
            DistributedMutex.synchronize("update_telegram_user_avatar_#{user.id}") do
              begin
                max = Discourse.avatar_sizes.max

                download_url =
                  "https://api.telegram.org/file/bot#{bot.bot_token}/#{file_path_res["result"]["file_path"]}"

                puts "download from #{download_url}"

                if SiteSetting.verbose_upload_logging
                  Rails.logger.warn(
                    "Verbose Upload Logging: Downloading tg avatar from #{download_url}",
                  )
                end

                # follow redirects in case tgavatar change rules on us
                tempfile =
                  FileHelper.download(
                    download_url,
                    max_file_size: SiteSetting.max_image_size_kb.kilobytes,
                    tmp_file_name: "tgavatar_for_#{user.id}",
                    skip_rate_limit: true,
                    verbose: false,
                    follow_redirect: true,
                  )

                if tempfile
                  ext = File.extname(tempfile)
                  ext = ".png" if ext.blank?

                  upload =
                    UploadCreator.new(
                      tempfile,
                      "tgavatar_for_#{user.id}#{ext}",
                      origin: download_url,
                      type: "avatar",
                    ).create_for(user.id)

                  puts "Upload ok: id = #{upload.id}"

                  user.update!(uploaded_avatar_id: upload.id)

                  ::ChatBridgeModule::Provider::TelegramBridge::ChatBridgeTelegramUserInfo.create_or_update!(
                    user_id: user.id,
                    tg_user_id: message["from"]["id"],
                    avatar_file_id: response["result"]["photos"][0][0]["file_id"],
                  )
                end
              rescue OpenURI::HTTPError => e
                raise e if e.io&.status[0].to_i != 404
              ensure
                tempfile&.close!
              end
            end
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
