# frozen_string_literal: true

module ::ChatBridgeModule
  module Provider
    module TelegramBridge
      class TelegramBot
        def initialize(discourse_chat_channel_id)
          @valid = false
          raise "No channel id" if discourse_chat_channel_id.nil?

          SiteSetting
            .chat_telegram_bridges
            .split("|")
            .each do |config|
              cid, gid, tok = config.split(",")
              if cid.to_i == discourse_chat_channel_id.to_i
                @group_id = gid
                @token = tok
                @valid = true
              end
            end
        end

        def valid?
          @valid
        end

        def bot_token
          @token
        end

        def group_id
          @group_id
        end

        def _request(methodName, message)
          raise "Telegram bot is not valid" unless @valid

          http = FinalDestination::HTTP.new("api.telegram.org", 443)
          http.use_ssl = true

          uri = URI("https://api.telegram.org/bot#{@token}/#{methodName}")

          Rails.logger.debug(
            "Sending Telegram API request to: https://api.telegram.org/bot#{@token}/#{methodName}" +
              "param: \n#{YAML.dump(message)}",
          )

          req = Net::HTTP::Post.new(uri, "Content-Type" => "application/json")
          req.body = message.to_json
          response = http.request(req)

          responseData = JSON.parse(response.body)

          responseData
        end

        def download_file_from_file_id(**para, &after_download)
          user, file_id, type, filename = para[:user], para[:file_id], para[:type], para[:filename]

          type ||= "composer"
          filename ||= "#{Time.now.to_i}"

          file_path_res = _request("getFile", { file_id: })

          if file_path_res["ok"] && file_path_res["result"] && file_path_res["result"]["file_path"]
            DistributedMutex.synchronize("download_file_#{file_id}for_#{user.id}") do
              begin
                max = Discourse.avatar_sizes.max

                download_url =
                  "https://api.telegram.org/file/bot#{@token}/#{file_path_res["result"]["file_path"]}"

                Rails.logger.debug("\n\nDownloading Telegram file from #{download_url}\n\n")

                if SiteSetting.verbose_upload_logging
                  Rails.logger.warn(
                    "Verbose Upload Logging: Downloading Tg file #{file_id} from #{download_url}",
                  )
                end

                # follow redirects in case tgavatar change rules on us
                tempfile =
                  FileHelper.download(
                    download_url,
                    max_file_size: SiteSetting.max_image_size_kb.kilobytes,
                    tmp_file_name: "#{filename}",
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
                      "#{filename}#{ext}",
                      origin: download_url,
                      type:,
                    ).create_for(user.id)

                  after_download.call upload
                end
              rescue OpenURI::HTTPError => e
                raise e if e.io&.status[0].to_i != 404
              ensure
                tempfile&.close!
              end
            end
          end
        end

        def get_upload_from_file(**para, &after_get)
          user, file, type, filename = para[:user], para[:file], para[:type], para[:filename]

          return nil if file["file_id"].nil?

          if file["file_unique_id"].present?
            existed_upload =
              ::ChatBridgeModule::Provider::TelegramBridge::ChatBridgeTelegramUpload.find_by(
                unique_id: file["file_unique_id"],
              )
            if existed_upload.present?
              upload = Upload.find_by(id: existed_upload.upload_id)
              upload.user_id = user.id
              upload.save!
              after_get.call upload
              return nil
            end
            download_file_from_file_id(user:, file_id: file["file_id"], type:, filename:) do |upl|
              ::ChatBridgeModule::Provider::TelegramBridge::ChatBridgeTelegramUpload.create!(
                unique_id: file["file_unique_id"],
                upload_id: upl.id,
              )
              after_get.call upl
            end
          end
        end
      end

      def self.setup_webhook
        newSecret = SecureRandom.hex
        SiteSetting.chat_telegram_bridge_secret_path = newSecret

        message = { url: Discourse.base_url + "/chat-bridge/telegram/hook/" + newSecret }

        SiteSetting
          .chat_telegram_bridges
          .split("|")
          .map do |config|
            cid, gid, tok = config.split(",")
            raise "Not valid config" if (cid.nil? || gid.nil? || tok.nil?)
            cid
          end
          .uniq
          .each do |cid|
            bot = ::ChatBridgeModule::Provider::TelegramBridge::TelegramBot.new(cid)
            response = bot._request("setWebhook", message)
            if response["ok"] != true
              # If setting up webhook failed, disable provider
              # SiteSetting.chat_bridge_enabled = false
              Rails.logger.error(
                "Failed to setup telegram webhook for chat channel #{cid}. Message data= " +
                  message.to_json + " response=" + response.to_json,
              )
            end
          end
      end

      def self.getChannelId?(groupId)
        return nil if groupId.nil?

        SiteSetting
          .chat_telegram_bridges
          .split("|")
          .each do |config|
            cid, gid, tok = config.split(",")
            return cid if gid.to_s == groupId.to_s
          end

        nil
      end

      class TelegramEvent < DiscourseEvent
      end

      class TelegramWebhookController < ::ApplicationController
        requires_plugin ::ChatBridgeModule::PLUGIN_NAME

        before_action :telegram_token_valid?, only: :hook
        skip_before_action :check_xhr,
                           :preload_json,
                           :verify_authenticity_token,
                           :redirect_to_login_if_required,
                           only: :hook

        def hook
          %i[
            message
            edited_message
            channel_post
            edited_channel_post
            inline_query
            chosen_inline_result
            callback_query
            shipping_query
            pre_checkout_query
            poll
            poll_answer
            my_chat_member
            chat_member
            chat_join_request
          ].each do |symbol|
            if params.key?(symbol.to_s)
              ::ChatBridgeModule::Provider::TelegramBridge::TelegramEvent.trigger(
                symbol,
                params[symbol.to_s],
              )
            end
          end

          # Always give telegram a success message, otherwise we'll stop receiving webhooks
          data = { success: true }
          render json: data
        end

        def telegram_token_valid?
          params.require(:token)

          if SiteSetting.chat_telegram_bridge_secret_path.blank? ||
               SiteSetting.chat_telegram_bridge_secret_path != params[:token]
            raise Discourse::InvalidAccess.new
          end
        end
      end

      class TelegramEngine < ::Rails::Engine
        engine_name ::ChatBridgeModule::PLUGIN_NAME + "-telegram"
        isolate_namespace ::ChatBridgeModule::Provider::TelegramBridge
      end

      TelegramEngine.routes.draw { post "hook/:token" => "telegram_webhook#hook" }

      Discourse::Application.routes.prepend { mount TelegramEngine, at: "chat-bridge/telegram" }
    end
  end
end
