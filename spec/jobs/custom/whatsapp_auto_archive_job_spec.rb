require 'rails_helper'

RSpec.describe Custom::WhatsappAutoArchiveJob do
  let(:channel) do
    create(:channel_whatsapp, provider: 'native', validate_provider_config: false, sync_templates: false,
                              provider_config: { 'mark_as_read' => true, Custom::WhatsappChatState::AUTO_ARCHIVE_KEY => true })
  end
  let(:backend) { Whatsapp::Session::Backends::Fake.new(channel) }
  let(:conversation) { create(:conversation, inbox: channel.inbox, account: channel.account) }
  let(:archives) { backend.commands.grep(Whatsapp::Session::Model::Commands::ChatArchive) }

  before { allow(Whatsapp::Session::Registry).to receive(:backend_for).and_return(backend) }

  it 'archives when the message is still the last one of the conversation' do
    message = create(:message, conversation: conversation, message_type: :outgoing, source_id: '3EB0AAAA')

    described_class.perform_now(message.id)

    expect(archives.size).to eq(1)
    expect(archives.first.to_h).to include('archive' => true)
  end

  it 'does nothing when the contact answered in the meantime' do
    message = create(:message, conversation: conversation, message_type: :outgoing, source_id: '3EB0AAAA', created_at: 1.minute.ago)
    create(:message, conversation: conversation, message_type: :incoming, source_id: '3EB0BBBB')

    described_class.perform_now(message.id)

    expect(archives).to be_empty
  end

  it 'leaves a burst to the job of its last message' do
    first = create(:message, conversation: conversation, message_type: :outgoing, source_id: '3EB0AAAA', created_at: 1.minute.ago)
    last = create(:message, conversation: conversation, message_type: :outgoing, source_id: '3EB0BBBB')

    described_class.perform_now(first.id)
    described_class.perform_now(last.id)

    expect(archives.size).to eq(1)
  end

  it 'does nothing once the inbox turned the option off' do
    message = create(:message, conversation: conversation, message_type: :outgoing, source_id: '3EB0AAAA')
    channel.update!(provider_config: { 'mark_as_read' => true })

    described_class.perform_now(message.id)

    expect(archives).to be_empty
  end
end
