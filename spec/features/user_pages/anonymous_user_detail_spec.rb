require 'spec_helper'

feature "View User Profile (Anonymouse User)" do
  
  given(:user) { FactoryGirl.create(:user) }
  
  scenario "Anonymous user sees all fields but no controls on any user profile" do
    visit user_path(user)
    page.should have_text(user.name)
    page.should_not have_link("Change account info")
    page.should_not have_link("Change picture")
  end

end
