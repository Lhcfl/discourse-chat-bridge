# frozen_string_literal: true

module ::ChatBridgeModule
  module Provider
    module MatrixBridge
      PROVIDER_ID = 2
      PROVIDER_SLUG = "Matrix".freeze
    end
  end
end

module ::ChatBridgeModule::Provider::MatrixBridge

  # Not implimented

  # DiscourseEvent.on(:chat_message_created) do |message, channel, user|
  #   Scheduler::Defer.later("Bridge chat_message_created to matrix") do
      
  #   end
  # end

end