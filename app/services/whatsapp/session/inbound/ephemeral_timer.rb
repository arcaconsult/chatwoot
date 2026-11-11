# Arcaconsult: the disappearing-message timer of a chat, in seconds, as the last message
# that arrived (or that the connected phone sent) carried it. Kept on the conversation so a
# reply typed in Chatwoot goes out under the same timer (Outbound::MessageSender); without
# it the reply is a normal message in a disappearing chat and the contact's phone says it
# will not disappear. Zero means the chat turned disappearing messages off.
module Whatsapp::Session::Inbound::EphemeralTimer
  KEY = 'whatsapp_ephemeral'.freeze

  module_function

  # Written into the JSON column atomically and only when it changes, without the
  # conversation's callbacks: it is bookkeeping for the sender, not something an agent or
  # an automation acts on, and a merge done in Ruby would race the other writers of
  # additional_attributes.
  #
  # Only from a message that carries the chat's context: a placeholder for one that could not
  # be read, or a reaction, says nothing about the timer.
  def remember(conversation, inbound)
    return if inbound.content.nil? || %w[reaction unsupported].include?(inbound.content.wire_type)

    seconds = inbound.ephemeral.to_i
    return if conversation.additional_attributes.to_h[KEY] == seconds

    Conversation.where(id: conversation.id).update_all( # rubocop:disable Rails/SkipsModelValidations
      [
        "additional_attributes = COALESCE(additional_attributes, '{}'::jsonb) || jsonb_build_object(?::text, ?::integer)",
        KEY, seconds
      ]
    )
    conversation.additional_attributes = conversation.additional_attributes.to_h.merge(KEY => seconds)
    conversation.clear_attribute_changes([:additional_attributes])
  end

  # The timer to send under, or nil when the chat has none.
  def for(conversation)
    conversation.additional_attributes.to_h[KEY].to_i.nonzero?
  end
end
