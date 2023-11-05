# frozen_string_literal: true

module ::ChatBridgeModule
  module Provider
    module TelegramBridge
      class Parser     
        def initialize (str, entities)
          @only_str = str
          @entities = entities
          @entities_grouped = []
          group = []
          o_a_now = 0
          far_b_now = 0
          @entities.keys.map do |k|
            @entities[k]
          end .each do |ent|
            o_a, o_b = ent["offset"].to_i, ent["offset"].to_i + ent["length"].to_i
            if o_a != o_a_now
              @entities_grouped.push(group)
              @entities_grouped.push([{ o_a: far_b_now, o_b: o_a, ent: { type: "plain" } }]) if o_a != far_b_now
              o_a_now = o_a
              group = []
            end
            group.unshift({ o_a:, o_b:, ent: })
            far_b_now = [o_b, far_b_now].max
          end
          @entities_grouped.push(group)
          @entities_grouped.push([{
            o_a: far_b_now,
            o_b: 1145141919810,
            ent: { type: "plain" }
          }])
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
        return nil if message["text"].blank?
        return message["text"] if message["entities"].blank?
        
        ::ChatBridgeModule::Provider::TelegramBridge::Parser.parse(message["text"], message["entities"])
      end

    end
  end
end
