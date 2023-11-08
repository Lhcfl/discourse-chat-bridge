# frozen_string_literal: true

RSpec.describe ::ChatBridgeModule::CreateMessage do

  describe ".call" do
    subject(:result) { described_class.call(params) }

    fab!(:user) { Fabricate(:user) }
    fab!(:other_user) { Fabricate(:user) }
    fab!(:channel) { Fabricate(:chat_channel, threading_enabled: true) }
    fab!(:thread) { Fabricate(:chat_thread, channel: channel) }
    fab!(:upload) { Fabricate(:upload, user: user) }
    fab!(:draft) { Fabricate(:chat_draft, user: user, chat_channel: channel) }

    let(:guardian) { user.guardian }
    let(:content) { "A new message @#{other_user.username_lower}" }
    let(:params) do
      { guardian: guardian, chat_channel_id: channel.id, message: content, upload_ids: [upload.id] }
    end
    let(:message) { result[:message_instance].reload }

    shared_examples "creating a new message" do
      it "saves the message" do
        expect { result }.to change { Chat::Message.count }.by(1)
        expect(message).to have_attributes(message: content)
      end

      it "attaches uploads" do
        expect(message.uploads).to match_array(upload)
      end

      it "publishes the new message" do
        Chat::Publisher.expects(:publish_new!).with(channel, instance_of(Chat::Message), nil)
        result
      end

      it "can enqueue a job to process message" do
        params[:process_inline] = false
        expect_enqueued_with(job: Jobs::Chat::ProcessMessage) { result }
      end

      it "can process a message inline" do
        params[:process_inline] = true
        Jobs::Chat::ProcessMessage.any_instance.expects(:execute).once
        expect_not_enqueued_with(job: Jobs::Chat::ProcessMessage) { result }
      end

      it "triggers a Discourse event" do
        DiscourseEvent.expects(:trigger).with(
          :chat_message_created,
          instance_of(Chat::Message),
          channel,
          user,
        )
        result
      end

      it "processes the direct message channel" do
        Chat::Action::PublishAndFollowDirectMessageChannel.expects(:call).with(
          channel_membership: membership,
        )
        result
      end
    end

    context "when user is silenced" do
      before { UserSilencer.new(user).silence }

      it { is_expected.to fail_a_policy(:no_silenced_user) }
    end

    context "when user is not silenced" do
      context "when mandatory parameters are missing" do
        before { params[:chat_channel_id] = "" }

        it { is_expected.to fail_a_contract }
      end

      context "when mandatory parameters are present" do
        context "when channel model is not found" do
          before { params[:chat_channel_id] = -1 }

          it { is_expected.to fail_to_find_a_model(:channel) }
        end

        context "when channel model is found" do
          context "when user is a ghost" do
            let(:guardian) { ::ChatBridgeModule::GhostUserGuardian.new }

            it { is_expected.to be_a_success }
          end
        end
      end
    end
  end
end