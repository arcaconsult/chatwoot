# Arcaconsult: adds the one automation action Chatwoot's own set doesn't have --
# `assignee_agent_bot_id` (the AI Agent Bot's own ownership marker on a conversation, distinct
# from `assignee_id`, the human agent's) never gets cleared by the stock `remove_assigned_agent`
# action, because CE's own Conversation callback only clears it as a side effect of a NEW human
# assignee being set (`reset_agent_bot_when_assignee_present`, app/models/conversation.rb):
#
#   def reset_agent_bot_when_assignee_present
#     return if assignee_id.blank?
#     self.assignee_agent_bot_id = nil
#   end
#
# Our routing deliberately leaves conversations in the team's queue with NO human assignee (so
# any available agent can pick one up), which means that callback's guard clause always returns
# early and the bot's ownership marker lingers forever -- the conversation keeps showing the
# fazer.ai persona's name as if it were still "handling" it, even after set_labels +
# assign_team + open_conversation ran. This adds a fourth automation action that clears it
# directly, sidestepping that guard rather than fighting it.
#
# Registered as an available action name in custom/app/models/custom/automation_rule.rb;
# selectable in the Automation Rule editor once app/javascript's constants.js and locale files
# know about it too (those two aren't Ruby, so they're edited directly -- see actionCable.js in
# this same custom/ tree for why that's the one part of these fixes that isn't a prepend).
module Custom::ActionService
  def remove_assigned_bot(_params)
    @conversation.with_lock { @conversation.update!(assignee_agent_bot_id: nil) }
  end
end
