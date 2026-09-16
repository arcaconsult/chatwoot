# Arcaconsult: registers the `remove_assigned_bot` action (defined in
# custom/app/services/custom/action_service.rb) as a name the AutomationRule model accepts and
# validates against -- without this, saving a rule that references it would fail validation
# even though ActionService itself already knows how to execute it.
module Custom::AutomationRule
  def actions_attributes
    super + %w[remove_assigned_bot]
  end
end
