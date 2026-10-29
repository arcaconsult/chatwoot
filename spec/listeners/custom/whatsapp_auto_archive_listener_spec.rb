require 'rails_helper'

RSpec.describe Custom::WhatsappAutoArchiveListener do
  let(:listener) { described_class.instance }
  let(:channel) do
    create(:channel_whatsapp, provider: 'native', validate_provider_config: false, sync_templates: false,
                              provider_config: { 'mark_as_read' => true, Custom::WhatsappChatState::AUTO_ARCHIVE_KEY => true })
  end
  let(:conversation) { create(:conversation, inbox: channel.inbox, account: channel.account) }

  def event_for(message)
    Events::Base.new('message.created', Time.zone.now, message: message)
  end

  it 'schedules the archive after an outgoing message in a 1:1 conversation' do
    message = create(:message, conversation: conversation, message_type: :outgoing)

    expect { listener.message_created(event_for(message)) }
      .to have_enqueued_job(Custom::WhatsappAutoArchiveJob).with(message.id)
  end

  it 'never schedules one for a group' do
    conversation.update!(group_type: :group)
    message = create(:message, conversation: conversation, message_type: :outgoing)

    expect { listener.message_created(event_for(message)) }.not_to have_enqueued_job(Custom::WhatsappAutoArchiveJob)
  end

  it 'ignores incoming messages and private notes' do
    incoming = create(:message, conversation: conversation, message_type: :incoming)
    note = create(:message, conversation: conversation, message_type: :outgoing, private: true)

    expect do
      listener.message_created(event_for(incoming))
      listener.message_created(event_for(note))
    end.not_to have_enqueued_job(Custom::WhatsappAutoArchiveJob)
  end

  it 'leaves an inbox without the option alone' do
    channel.update!(provider_config: { 'mark_as_read' => true })
    message = create(:message, conversation: conversation, message_type: :outgoing)

    expect { listener.message_created(event_for(message)) }.not_to have_enqueued_job(Custom::WhatsappAutoArchiveJob)
  end

  it 'is registered on the async dispatcher' do
    expect(AsyncDispatcher.new.listeners).to include(listener)
  end
end
