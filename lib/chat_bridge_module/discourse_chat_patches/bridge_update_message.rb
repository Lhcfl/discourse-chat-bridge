# frozen_string_literal: true

module ChatBridgeModule
  # Service responsible for updating a message.
  #
  # @example
  #  Chat::UpdateMessage.call(message_id: 2, guardian: guardian, message: "A new message")
  #
  class UpdateMessage < Chat::UpdateMessage
    include Service::Base

    # @!method call(message_id:, guardian:, message:, upload_ids:)
    #   @param guardian [Guardian]
    #   @param message_id [Integer]
    #   @param message [String]
    #   @param upload_ids [Array<Integer>] IDs of uploaded documents

    contract
    model :message
    model :uploads, optional: true

    transaction do
      step :modify_message
      step :save_message
      step :save_revision
      step :publish
    end

  end
end
