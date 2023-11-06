# frozen_string_literal: true

module ::ChatBridgeModule
  module Provider
    module TelegramBridge
      class Parser
        def initialize(str, entities)
          @only_str = str
          @entities = entities
          @entities_grouped = []
          group = []
          o_a_now = 0
          far_b_now = 0
          @entities
            .keys
            .map { |k| @entities[k] }
            .each do |ent|
              o_a, o_b = ent["offset"].to_i, ent["offset"].to_i + ent["length"].to_i
              if o_a != o_a_now
                @entities_grouped.push(group)
                if o_a != far_b_now
                  @entities_grouped.push([{ o_a: far_b_now, o_b: o_a, ent: { type: "plain" } }])
                end
                o_a_now = o_a
                group = []
              end
              group.unshift({ o_a:, o_b:, ent: })
              far_b_now = [o_b, far_b_now].max
            end
          @entities_grouped.push(group)
          @entities_grouped.push(
            [{ o_a: far_b_now, o_b: 1_145_141_919_810, ent: { type: "plain" } }],
          )
          @result = []
          @entities_grouped.each do |grouped|
            rendered_text = []
            o_a = -1
            grouped.each do |ent|
              o_a = ent[:o_a] if o_a == -1
              o_b = ent[:o_b]
              if true
                rendered_text.push @only_str[o_a...o_b]
                case ent[:ent]["type"]
                when "bold"
                  rendered_text.unshift("**")
                  rendered_text.push("**")
                when "strikethrough"
                  rendered_text.unshift("~~")
                  rendered_text.push("~~")
                when "italic"
                  rendered_text.unshift("*")
                  rendered_text.push("*")
                when "text_link"
                  rendered_text.unshift("[")
                  rendered_text.push("](#{ent[:ent]["url"]})")
                when "pre"
                  rendered_text.unshift("\n```#{ent[:ent]["language"]}\n")
                  rendered_text.push("\n```\n")
                when "code"
                  rendered_text.unshift("`")
                  rendered_text.push("`")
                else
                  # do nothing
                end
              end
              o_a = o_b
            end
            @result.push(rendered_text.join(""))
          end
        end
        def result
          @result.join("")
        end
        def self.parse(str, entities)
          self.new(str, entities).result
        end
      end

      def self.make_markdown_from_message(message)
        if message["text"].present?
          return message["text"] if message["entities"].blank?
          return(
            ::ChatBridgeModule::Provider::TelegramBridge::Parser.parse(
              message["text"],
              message["entities"],
            )
          )
        elsif message["caption"].present?
          return message["caption"] if message["caption_entities"].blank?
          return(
            ::ChatBridgeModule::Provider::TelegramBridge::Parser.parse(
              message["caption"],
              message["caption_entities"],
            )
          )
        end
        ""
      end

      def self.make_discourse_message(bot, user, msg)
        message = ::ChatBridgeModule::Provider::TelegramBridge.make_markdown_from_message(msg)
        upload_ids = []
        in_reply_to_id = nil

        if msg["reply_to_message"]
          in_reply_to_id =
            ::ChatBridgeModule::Provider::TelegramBridge::ChatBridgeTelegramMessage
              .find_by(
                tg_msg_id: msg["reply_to_message"]["message_id"],
                tg_chat_id: msg["chat"]["id"],
              )
              &.discourse_message
              &.id
        end

        if msg["photo"].present?
          begin
            puts "Getting photo"
            puts msg["photo"]
            puts "----------"
            bot.get_upload_from_file(
              user:,
              file: msg["photo"][msg["photo"].keys[-1]],
              type: "chat-composer",
              filename: "photo",
            ) { |upload| upload_ids.push(upload.id) }
          rescue => exception
            Rails.logger.warn(
              "[Telegram Bridge] Received a telegram message with photo got error. details: #{JSON.dump(exception)}",
            )
          end
        end

        if msg["sticker"].present?
          begin
            puts "Getting sticker"
            puts msg["sticker"]
            puts "----------"
            bot.get_upload_from_file(
              user:,
              file: msg["sticker"],
              type: "chat-composer",
              filename: "sticker-#{msg["sticker"]["emoji"]}",
            ) { |upload| upload_ids.push(upload.id) }
          rescue => exception
            Rails.logger.warn(
              "[Telegram Bridge] Received a telegram message with sticker got error. details: #{JSON.dump(exception)}",
            )
          end
        end

        message = "[This message is not supported yet]" if message.blank? && upload_ids.blank?

        { message:, upload_ids:, in_reply_to_id: }
      end
    end
  end
end
