require 'rails_helper'

RSpec.describe Custom::WhatsappChatState do
  subject(:chat_state) { described_class.new(conversation) }

  let(:channel) { create(:channel_whatsapp, provider: 'native', validate_provider_config: false, sync_templates: false) }
  let(:inbox) { channel.inbox }
  let(:backend) { Whatsapp::Session::Backends::Fake.new(channel) }
  let(:contact) { create(:contact, account: channel.account, phone_number: '+5541999990000') }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox, source_id: '5541999990000') }
  let(:conversation) { create(:conversation, contact: contact, contact_inbox: contact_inbox, inbox: inbox, account: channel.account) }

  before { allow(Whatsapp::Session::Registry).to receive(:backend_for).and_return(backend) }

  describe '#archive!' do
    it 'archives the chat as of the newest message that has a WhatsApp id' do
      create(:message, conversation: conversation, message_type: :incoming, source_id: '3EB0OLD', created_at: 2.minutes.ago)
      create(:message, conversation: conversation, message_type: :outgoing, source_id: '3EB0NEW', created_at: 1.minute.ago,
                       content_attributes: { 'external_created_at' => 1_755_439_990 })
      create(:message, conversation: conversation, message_type: :outgoing, source_id: nil)
      create(:message, conversation: conversation, message_type: :activity, content: 'resolvida')

      chat_state.archive!(true)

      command = backend.commands.last
      expect(command).to be_a(Whatsapp::Session::Model::Commands::ChatArchive)
      expect(command.to_h).to eq(
        'chat' => { 'kind' => 'phone', 'id' => '5541999990000' }, 'archive' => true,
        'last_message' => { 'id' => '3EB0NEW', 'timestamp' => 1_755_439_990_000, 'from_me' => true }
      )
    end

    it 'unarchives with no anchor when nothing in the conversation reached WhatsApp' do
      chat_state.archive!(false)

      expect(backend.commands.last.to_h).to eq('chat' => { 'kind' => 'phone', 'id' => '5541999990000' }, 'archive' => false)
    end

    it 'produces a frame the vendored contract accepts' do
      create(:message, conversation: conversation, message_type: :outgoing, source_id: '3EB0NEW')
      chat_state.archive!(true)

      payload = backend.commands.last.to_h.compact
      expect(Whatsapp::SessionContract.schema['definitions']).to have_key('command_chat_archive')
      validator = JSONSchemer.schema({ '$ref' => '#/definitions/command_chat_archive',
                                       'definitions' => Whatsapp::SessionContract.schema['definitions'] })
      expect(validator.valid?(payload)).to be(true)
    end
  end

  describe '#mute!' do
    it 'mutes until the end of the chosen duration' do
      freeze_time do
        chat_state.mute!(true, duration: '8h')

        expect(backend.commands.last.to_h).to include('mute' => true, 'until' => (8.hours.from_now.to_f * 1000).to_i)
      end
    end

    it 'mutes for good with no end' do
      chat_state.mute!(true, duration: 'always')

      expect(backend.commands.last.to_h).to eq('chat' => { 'kind' => 'phone', 'id' => '5541999990000' }, 'mute' => true)
    end

    it 'unmutes, ignoring the duration' do
      chat_state.mute!(false, duration: '1w')

      expect(backend.commands.last.to_h).to eq('chat' => { 'kind' => 'phone', 'id' => '5541999990000' }, 'mute' => false)
    end

    it 'refuses a duration it does not know' do
      expect { chat_state.mute!(true, duration: '3d') }.to raise_error(ArgumentError)
      expect(backend.commands).to be_empty
    end
  end

  it 'refuses an inbox that is not a session WhatsApp' do
    api_conversation = create(:conversation)

    expect { described_class.new(api_conversation).archive!(true) }.to raise_error(described_class::Unsupported)
  end

  describe '.auto_archive?' do
    it 'is off unless the inbox turned it on' do
      expect(described_class.auto_archive?(inbox)).to be(false)

      channel.update!(provider_config: channel.provider_config.merge(described_class::AUTO_ARCHIVE_KEY => true))
      expect(described_class.auto_archive?(inbox.reload)).to be(true)
    end

    it 'is off for an inbox of another kind even with the key' do
      expect(described_class.auto_archive?(create(:inbox))).to be(false)
    end
  end
end
