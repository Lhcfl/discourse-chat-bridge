# frozen_string_literal: true

module ::ChatBridgeModule::Provider::TelegramBridge
  class Parser
    def initialize(str, entities)
      @only_str = str

      if entities.class == Array
        @entities = entities
      else
        @entities = entities.keys.map { |k| entities[k] }
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
      @entities_grouped.push([{ o_a: far_b_now, o_b: 1_145_141_919_810, ent: { type: "plain" } }])
      @result = []
      @entities_grouped.each do |grouped|
        rendered_text = []
        o_a = -1
        grouped.each do |ent|
          o_a = ent[:o_a] if o_a == -1
          o_b = ent[:o_b]

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
end
