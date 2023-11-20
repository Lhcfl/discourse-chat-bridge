# frozen_string_literal: true

module ::ChatBridgeModule
  # should follow: plugins/chat/app/services/chat/create_message.rb
  class CreateMessage < Chat::CreateMessage
    policy :no_silenced_user
    contract
    model :channel
    model :reply, optional: true
    policy :ensure_reply_consistency
    model :thread, optional: true
    policy :ensure_valid_thread_for_channel
    policy :ensure_thread_matches_parent
    model :uploads, optional: true
    model :message_instance, :instantiate_message
    transaction do
      step :save_message
      step :post_process_thread
      step :create_webhook_event
      step :update_channel_last_message
    end
    step :publish_new_thread
    step :process
    step :publish_user_tracking_state
  end
end
