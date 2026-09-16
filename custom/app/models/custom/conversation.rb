# Arcaconsult: uma conversa que um AGENTE cria (Current.user presente — ex.: pelo formulário
# "Nova conversa") não deve herdar o padrão do bot (pending, atribuída ao bot) — esse padrão
# existe pra primeira mensagem de um CLIENTE, não pra um contato que o próprio agente inicia.
#
# Em vez disso: aberta, atribuída a esse agente. Quando o agente pertence a EXATAMENTE um
# time, a conversa também é classificada nesse time e etiquetada com o mesmo nome (mesma
# convenção em minúsculas que o set_labels já usa: "financeiro", "suporte", "comercial",
# "ecommerce"). Um agente em zero ou vários times (ex.: um admin que está em todos) não tem
# um time único pra inferir, então time e etiqueta ficam de fora — o agente classifica na mão.
module Custom::Conversation
  def self.prepended(base)
    base.after_create :label_by_creating_agent_team
    base.after_create :label_and_exclude_bot_for_group_conversations
  end

  def set_active_bot_conversation
    # ARCACONSULT: conversa de grupo nunca fica com o bot — nem pending, nem
    # atribuída a ele. Sem isso, o gate de ownership do fazer.ai agents nunca
    # teria motivo pra recusar o turno, e a IA respondia grupo normalmente.
    return if group_type_group?
    return assign_to_creating_agent if Current.user.present?

    super
  end

  private

  def assign_to_creating_agent
    self.status = :open
    self.assignee_id = Current.user.id

    teams = Current.user.teams
    return unless teams.count == 1

    self.team_id = teams.first.id
  end

  def label_by_creating_agent_team
    return unless Current.user.present?

    teams = Current.user.teams
    return unless teams.count == 1

    update!(label_list: [teams.first.name.downcase])
  end

  def label_and_exclude_bot_for_group_conversations
    return unless group_type_group?

    update!(label_list: (label_list + ['grupo']).uniq)
  end
end
