# Arcaconsult: arquiva no WhatsApp do dono da caixa a conversa individual que acabou de
# receber uma mensagem enviada (pelo Chatwoot ou pelo celular, que chega como eco).
#
# Roda com atraso (DELAY) por dois motivos: uma mensagem enviada pelo Chatwoot só ganha o
# id do WhatsApp (source_id) depois que o envio volta, e é nela que o arquivamento se
# ancora; e uma rajada de mensagens vira um arquivamento só, o da última. Se, quando o job
# roda, a mensagem que o disparou não é mais a última da conversa (o contato respondeu, ou
# saiu outra mensagem depois), ele não faz nada: quem decide é o job da última.
class Custom::WhatsappAutoArchiveJob < ApplicationJob
  queue_as :low

  DELAY = 20.seconds

  def perform(message_id)
    message = Message.find_by(id: message_id)
    return if message.nil?

    conversation = message.conversation
    return if conversation.group_type_group?
    return unless Custom::WhatsappChatState.auto_archive?(conversation.inbox)

    latest = conversation.messages.where(message_type: %i[incoming outgoing]).reorder(created_at: :desc, id: :desc).first
    return unless latest == message

    Custom::WhatsappChatState.new(conversation).archive!(true)
  end
end
