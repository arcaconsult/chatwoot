# Arcaconsult: dispara o arquivamento automático (Custom::WhatsappAutoArchiveJob) quando
# sai uma mensagem numa conversa individual de uma caixa com a opção ligada
# (`provider_config['arca_auto_archive_outgoing'] == true`). Grupo nunca é arquivado.
# Nota privada não conta: não sai para o WhatsApp.
class Custom::WhatsappAutoArchiveListener < BaseListener
  def message_created(event)
    message = event.data[:message]
    return unless message.outgoing? && !message.private?

    conversation = message.conversation
    return if conversation.group_type_group?
    return unless Custom::WhatsappChatState.auto_archive?(conversation.inbox)

    Custom::WhatsappAutoArchiveJob.set(wait: Custom::WhatsappAutoArchiveJob::DELAY).perform_later(message.id)
  end
end
