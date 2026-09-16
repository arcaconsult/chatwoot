# Arcaconsult: grupo nunca pertence ao bot (custom/app/models/custom/conversation.rb já
# impede isso na criação) -- reabrir uma conversa de grupo resolvida não pode reverter
# essa regra jogando o status pra "pending" (que é o estado que sinaliza "o bot está
# com essa conversa"). Pra grupo, reabre direto como "open".
module Custom::Message
  def reopen_resolved_conversation
    return conversation.open! if conversation.group_type_group?

    super
  end
end
