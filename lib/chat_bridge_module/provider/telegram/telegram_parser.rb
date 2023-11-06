# frozen_string_literal: true

module ::ChatBridgeModule
  module Provider
    module TelegramBridge
      class Parser
        def initialize(str, entities)
          @only_str = str
          if entities.class == Array
            @entities = entities
          else
            @entities = entities.keys.map { |k| @entities[k] }
          end
          @entities_grouped = []
          group = []
          o_a_now = 0
          far_b_now = 0
          @entities.each do |ent|
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
                when "spoiler"
                  rendered_text.unshift("[spoiler]")
                  rendered_text.push("[/spoiler]")
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

      class TgHtml
        MARKDOWN_FEATURES = %w[
          bbcode-block
          bbcode-inline
          code
          html-img
          quotes
          spoiler-alert
          text-post-process
        ]

        MARKDOWN_IT_RULES = %w[
          autolink
          backticks
          newline
          code
          fence
          image
          link
          strikethrough
          blockquote
          emphasis
          replacements
        ]

        ALLOWED_HTML_TAG = %w[b strong i em u ins s strike del span tg-spoiler a code pre]

        def initialize(raw)
          # @result = PrettyText.cook(
          #   raw,
          #   features_override:
          #     MARKDOWN_FEATURES,
          #   markdown_it_rules: MARKDOWN_IT_RULES,
          #   force_quote_link: true,
          # )
          if raw.blank?
            @result = ""
            return nil
          end
          @result =
            raw.gsub (
                       %r{<aside class="onebox[^>]*?data-onebox-src="([^"]+)"[^>]*>[\s\S]+?</aside>}
                     ) do
              "<a href=\"#{$1}\">#{$1}</a>"
            end
          @result.gsub! (%r{<div class=\"spoiler\">([\s\S]+?)</div>}) {
            "<tg-spoiler>#{$1}</tg-spoiler>"
          }
          @result.gsub! (%r{<span class=\"spoiler\">([\s\S]+?)</span>}) {
            "<tg-spoiler>#{$1}</tg-spoiler>"
          }
          @result.gsub! (%r{<img src="/images/emoji/[^/]+/([^.]+)[^>]*>}) {
            Emoji.lookup_unicode($1)
          }

          @result.gsub! (/<([^>]+)>/) do |tag|
            parsed = $1.split(" ")
            if ALLOWED_HTML_TAG.include? parsed[0]
              case parsed[0]
              when "a"
                matched = tag.match(/href="([^"]+)"/)
                if (matched && matched[1])
                  "<a href=\"#{matched[1]}\">"
                else
                  '<a href="https://example.com">'
                end
              else
                "<#{parsed[0]}>"
              end
            elsif parsed[0][0] == "/" && ALLOWED_HTML_TAG.include?(parsed[0][1..])
              "<#{parsed[0]}>"
            else
              case tag
              when "<blockquote>"
                "<pre><code class=\"language-quote\">"
              when "</blockquote>"
                "</code></pre>"
              when "<p>"
                "\n"
              when "</p>"
                "\n"
              else
                nil
              end
            end
          end

          @result.gsub! (/:([^:]+):/) do |emo|
            ji = Emoji.lookup_unicode($1)
            if ji.present?
              ji
            else
              emo
            end
          end
        end

        def result
          @result
        end
        def self.parse(raw)
          self.new(raw).result.strip
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
            ) { |upload| upload_ids.push(upload.id) }
          rescue => exception
            Rails.logger.warn(
              "[Telegram Bridge] Received a telegram message with photo got error. details: #{JSON.dump(exception)}",
            )
          end
        end

        if msg["sticker"].present?
          begin
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

      def self.make_telegram_message(bot:, message:, channel:, user:, event:)
        # usage:
        # 0 - create
        # 1 - edit
        # 2 - trash

        to_send = { chat_id: bot.group_id, parse_mode: "HTML" }

        methodName = "sendMessage"

        if event == :chat_message_trashed
          the_message =
            ::ChatBridgeModule::Provider::TelegramBridge::ChatBridgeTelegramMessage.find_by(
              message_id: message.id,
            )
          return if the_message.blank?
          bot._request(
            "deleteMessage",
            { chat_id: bot.group_id, message_id: the_message.tg_msg_id },
          )
          return nil
        end

        if event == :chat_message_edited
          the_message =
            ::ChatBridgeModule::Provider::TelegramBridge::ChatBridgeTelegramMessage.find_by(
              message_id: message.id,
            )
          return if the_message.blank?
          to_send[:message_id] = the_message.tg_msg_id
          if JSON.parse(the_message.raw)["caption"].present?
            methodName = "editMessageCaption"
            to_send[
              :caption
            ] = "<b>#{user.username}</b>: #{::ChatBridgeModule::Provider::TelegramBridge::TgHtml.parse(message.cooked)}"
          else
            methodName = "editMessageText"
            to_send[
              :text
            ] = "<b>#{user.username}</b>: #{::ChatBridgeModule::Provider::TelegramBridge::TgHtml.parse(message.cooked)}"
          end
          return bot._request(methodName, to_send)
        end

        if message.in_reply_to_id.present?
          reply_to =
            ::ChatBridgeModule::Provider::TelegramBridge::ChatBridgeTelegramMessage.find_by(
              message_id: message.in_reply_to_id,
            )
          if reply_to.present?
            to_send[:reply_to_message_id] = reply_to.tg_msg_id
            to_send[:allow_sending_without_reply] = true
          end
        end

        if message.uploads.blank?
          to_send[
            :text
          ] = "<b>#{user.username}</b>: #{::ChatBridgeModule::Provider::TelegramBridge::TgHtml.parse(message.cooked)}"
        else
          methodName = "sendPhoto"
          to_send[
            :caption
          ] = "<b>#{user.username}</b>: #{::ChatBridgeModule::Provider::TelegramBridge::TgHtml.parse(message.cooked)}"
          to_send[:photo] = "#{Discourse.base_url}#{message.uploads[0].url}"
        end

        response_message = bot._request(methodName, to_send)

        response_message
      end
    end
  end
end
