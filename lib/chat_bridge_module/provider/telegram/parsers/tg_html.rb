# frozen_string_literal: true

module ::ChatBridgeModule::Provider::Telegram::Parsers

  # Parse discourse html to telegram html
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
        raw.gsub (%r{<aside class="onebox[^>]*?data-onebox-src="([^"]+)"[^>]*>[\s\S]+?</aside>}) do
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
end
