# Arcaconsult: the archive and mute half of the facade, carried by the connector patch
# on top of v0.8.5 (`chat.archive`, `chat.mute`). Split out because the facade is at the
# length the project allows, and so the fork's addition lives in a file of its own.
module Whatsapp::Session::Facade::ChatState
  # Archives or unarchives the conversation's chat on the account's own devices. Addressed
  # like `unread_message`, from the contact (or the group), and anchored on the newest
  # message that carries a WhatsApp id. Nothing reaches the people in it.
  def archive_conversation(conversation, archive:)
    raise Whatsapp::Session::Errors::NotSupported, 'archive' unless capability?('archive')

    last = conversation.messages.where(message_type: %i[incoming outgoing]).where.not(source_id: [nil, ''])
                       .reorder(created_at: :desc, id: :desc).first
    backend.archive_chat(
      model::Commands::ChatArchive.new(
        chat: model::Address.for_contact(conversation.contact), archive: archive,
        last_message: model::Commands::HistoryAnchor.for_message(last)
      )
    )
  end

  # Mutes the conversation's chat until `until_time` (a Time; nil is for good), or unmutes it.
  def mute_conversation(conversation, mute:, until_time: nil)
    raise Whatsapp::Session::Errors::NotSupported, 'mute' unless capability?('mute')

    ends_at = (until_time.to_f * 1000).to_i if mute && until_time
    backend.mute_chat(
      model::Commands::ChatMute.new(chat: model::Address.for_contact(conversation.contact), mute: mute, until: ends_at)
    )
  end
end
