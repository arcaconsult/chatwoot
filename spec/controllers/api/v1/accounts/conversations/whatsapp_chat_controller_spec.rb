require 'rails_helper'

RSpec.describe 'Conversation WhatsApp archive/mute API', type: :request do
  let(:channel) { create(:channel_whatsapp, provider: 'native', validate_provider_config: false, sync_templates: false) }
  let(:account) { channel.account }
  let(:backend) { Whatsapp::Session::Backends::Fake.new(channel) }
  let(:conversation) { create(:conversation, inbox: channel.inbox, account: account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:base) { "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}" }

  before do
    allow(Whatsapp::Session::Registry).to receive(:backend_for).and_return(backend)
    create(:inbox_member, inbox: channel.inbox, user: agent)
  end

  it 'refuses an unauthenticated request' do
    post "#{base}/whatsapp_archive", params: { archive: true }, as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  describe 'POST whatsapp_archive' do
    it 'queues an archive' do
      post "#{base}/whatsapp_archive", params: { archive: true }, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:accepted)
      expect(response.parsed_body).to include('archive' => true, 'status' => 'queued')
      expect(backend.commands.last.to_h).to include('archive' => true)
    end

    it 'queues an unarchive' do
      post "#{base}/whatsapp_archive", params: { archive: false }, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:accepted)
      expect(backend.commands.last.to_h).to include('archive' => false)
    end

    it 'refuses a missing or malformed flag' do
      post "#{base}/whatsapp_archive", params: { archive: 'sim' }, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(backend.commands).to be_empty
    end

    it 'refuses a conversation whose inbox is not a session WhatsApp' do
      other = create(:conversation, account: account)
      create(:inbox_member, inbox: other.inbox, user: agent)

      post "/api/v1/accounts/#{account.id}/conversations/#{other.display_id}/whatsapp_archive",
           params: { archive: true }, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'POST whatsapp_mute' do
    it 'mutes for a week' do
      post "#{base}/whatsapp_mute", params: { mute: true, duration: '1w' }, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:accepted)
      expect(response.parsed_body).to include('mute' => true, 'duration' => '1w')
      expect(backend.commands.last.to_h['until']).to be_within(60_000).of((1.week.from_now.to_f * 1000).to_i)
    end

    it 'mutes for good when no duration is given' do
      post "#{base}/whatsapp_mute", params: { mute: true }, headers: agent.create_new_auth_token, as: :json

      expect(response.parsed_body).to include('duration' => 'always')
      expect(backend.commands.last.to_h).to include('mute' => true)
      expect(backend.commands.last.to_h).not_to have_key('until')
    end

    it 'unmutes' do
      post "#{base}/whatsapp_mute", params: { mute: false }, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:accepted)
      expect(backend.commands.last.to_h).to include('mute' => false)
    end

    it 'refuses a duration it does not know' do
      post "#{base}/whatsapp_mute", params: { mute: true, duration: '3d' }, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(backend.commands).to be_empty
    end
  end
end
