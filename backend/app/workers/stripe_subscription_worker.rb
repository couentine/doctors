class StripeSubscriptionWorker
  include Sidekiq::Worker
  sidekiq_options queue: :high, :backtrace => true
  
  # This worker runs on app launch and ensures that all of the subscription plans
  # specified in the config yaml are created in stripe.

  # all_subscription_plans = { 'plan_id' => { 'name' => 'Standard', ... }, ... }
  def perform(all_subscription_plans)
    all_subscription_plans.each do |plan_id, plan_fields|
      plan = Stripe::Plan.retrieve(plan_id) rescue nil

      unless plan
        plan = Stripe::Plan.create(
          id: plan_id,
          name: plan_fields['name'],
          amount: plan_fields['amount'],
          currency: plan_fields['currency'],
          interval: plan_fields['interval'],
          trial_period_days: plan_fields['trial_period_days'],
          statement_descriptor: plan_fields['statement_descriptor'],
          metadata: {
            users: plan_fields['users'],
            admins: plan_fields['admins'],
            hub_member_groups_full: plan_fields['hub_member_groups_full'],
            hub_member_groups_limited: plan_fields['hub_member_groups_limited']
          }
        )
      end
    end
  end
end