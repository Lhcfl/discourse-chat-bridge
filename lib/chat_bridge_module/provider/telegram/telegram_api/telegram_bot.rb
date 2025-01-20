# frozen_string_literal: true

module ::ChatBridgeModule::Provider::Telegram::TelegramApi
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
          "\n\nparam: \n#{YAML.dump(message)}",
      )

      req = Net::HTTP::Post.new(uri, "Content-Type" => "application/json")
      req.body = message.to_json
      response = http.request(req)

      JSON.parse(response.body)
    end

    def download_file_from_file_id(**para, &after_download)
      user, file_id, type, filename, ext =
        para[:user],
        para[:file_id],
        para[:type],
        para[:filename],
        para[:ext]

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
              if ext.nil?
                ext = File.extname(tempfile)
                ext = ".png" if ext.blank?
              end

              puts "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n"
              puts tempfile
              puts "#{filename}#{ext}"
              puts YAML.dump(tempfile)
              puts "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n"

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
      user, file = para[:user], para[:file]

      return nil if file["file_id"].nil?

      if file["file_unique_id"].present?
        existed_upload =
          ::ChatBridgeModule::Provider::Telegram::ChatBridgeTelegramUpload.find_by(
            unique_id: file["file_unique_id"],
          )
        if existed_upload.present?
          if existed_upload.upload_id == nil
            existed_upload.destroy!
            existed_upload = nil
          else
            upload = Upload.find_by(id: existed_upload.upload_id)
            upload.user_id = user.id
            upload.save!
            after_get.call upload
            return nil
          end
        end
        download_file_from_file_id(file_id: file["file_id"], **para) do |upl|
          if upl&.id != nil
            ::ChatBridgeModule::Provider::Telegram::ChatBridgeTelegramUpload.create!(
              unique_id: file["file_unique_id"],
              upload_id: upl.id,
            )
            after_get.call upl
          end
        end
      end
    end
  end
end
