# frozen_string_literal: true

module ChatBridgeModule::Provider::Parsers
  module DiscourseMessage

    def make_markdown_from_message(message)
      if message["text"].present?
        return message["text"] if message["entities"].blank?
        return(
          TelegramMessage.parse(
            message["text"],
            message["entities"],
          )
        )
      elsif message["caption"].present?
        return message["caption"] if message["caption_entities"].blank?
        return(
          TelegramMessage.parse(
            message["caption"],
            message["caption_entities"],
          )
        )
      end
      ""
    end

    def make_display_forward(msg)
      if msg["forward_from"].present?
        result =
          ::ChatBridgeModule::Provider::Telegram::Parsers::TelegramMessage.make_display_name(msg["forward_from"])
      elsif msg["forward_sender_name"]
        result = msg["forward_sender_name"]
      elsif msg["forward_from_chat"]
        result =
          "[#{msg["forward_from_chat"]["title"]}](https://t.me/#{msg["forward_from_chat"]["username"]}/#{msg["forward_from_message_id"]})"
      else
        return ""
      end
      "***Forwarded from #{result}***\n"
    end

    def self.make(bot, user, msg)
      message =
        make_display_forward(msg) + make_markdown_from_message(msg)

      upload_ids = []
      in_reply_to_id = nil

      if msg["reply_to_message"]
        in_reply_to_id =
          ::ChatBridgeModule::Provider::Telegram::ChatBridgeTelegramMessage
            .find_by(
              tg_msg_id: msg["reply_to_message"]["message_id"],
              tg_chat_id: msg["chat"]["id"],
            )
            &.discourse_message
            &.id
      end

      if msg["photo"].present?
        begin
          photo = msg["photo"]
          if msg["photo"].class == Array
            photo = photo[-1]
          else
            photo = photo[photo.keys[-1]]
          end
          bot.get_upload_from_file(
            user:,
            file: photo,
            type: "chat-composer",
            filename: "photo",
          ) { |upload| upload.id and upload_ids.push(upload.id) }
        rescue => exception
          Rails.logger.warn(
            "[Telegram Bridge] Received a telegram message with photo got error. details: #{JSON.dump(exception)}",
          )
        end
      end

      if msg["sticker"].present?
        file = msg["sticker"]
        should_download = true
        upload_args = { ext: ".webp" }
        # TODO: support animated sticker
        if file["is_animated"] == "true" || file["is_animated"] == true
          if file["thumb"].present?
            file = file["thumb"]
            message += "*Animated sticker is not supported yet*"
          elsif file["thumbnail"].present?
            file = file["thumbnail"]
            message += "*Animated sticker is not supported yet*"
          else
            message += "[Sticker] #{msg["sticker"]["emoji"]} *This sticker is not supported yet*"
            should_download = false
          end
        end
        upload_args[:ext] = ".webm" if file["is_video"] == "true" || file["is_video"] == true
        if should_download
          begin
            bot.get_upload_from_file(
              user:,
              file:,
              type: "chat-composer",
              filename: "sticker-#{msg["sticker"]["emoji"]}",
              **upload_args,
            ) { |upload| upload.id and upload_ids.push(upload.id) }
          rescue => exception
            Rails.logger.warn(
              "[Telegram Bridge] Received a telegram message with sticker got error. details: #{JSON.dump(exception)}",
            )
          end
        end
      end

      if msg["document"].present?
        begin
          file = msg["document"]
          ext = file["file_name"] and file["file_name"].match(/\.[^\.]+$/)[0]
          bot.get_upload_from_file(
            user:,
            file:,
            type: "chat-composer",
            filename: file["file_name"] || "file",
            ext:,
          ) do |upload|
            if upload.id
              upload_ids.push(upload.id)
            else
              if file["thumb"].present? || ile["thumbnail"].present?
                file = file["thumb"] || file["thumbnail"]
                bot.get_upload_from_file(
                  user:,
                  file:,
                  type: "chat-composer",
                  filename: file["file_name"] || "file",
                ) { |upload2| upload2.id and upload_ids.push(upload2.id) }
              end
            end
          end
        rescue => exception
          Rails.logger.warn(
            "[Telegram Bridge] Received a telegram message with document got error. details: #{JSON.dump(exception)}",
          )
        end
      end

      message = "[This message is not supported yet]" if message.blank? && upload_ids.blank?

      { message:, upload_ids:, in_reply_to_id: }
    end
  end
end
